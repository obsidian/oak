class Oak::Tree(T)
  # :nodoc:
  struct Context(T)
    getter children = [] of Tree(T)
    getter payloads = [] of T

    def initialize(child : Tree(T)? = nil)
      children << child if child
    end

    def payload
      payloads.first
    end

    def payload?
      payloads.first?
    end
  end

  # The error class that is returned in the case of a shared key conflict.
  class SharedKeyError < Exception
    def initialize(new_key, existing_key)
      super("Tried to place key '#{new_key}' at same level as '#{existing_key}'")
    end
  end

  # :nodoc:
  enum Kind : UInt8
    Normal
    Named
    Glob
  end

  include Enumerable(Result(T))
  include Comparable(self)

  @root = false

  # The key of the current tree child
  getter key : String = ""
  protected getter priority : Int32 = 0
  protected getter context = Context(T).new
  protected getter kind = Kind::Normal

  # :nodoc:
  delegate payloads, payload, payload?, children, to: @context

  # :nodoc:
  delegate normal?, named?, glob?, to: kind
  # :nodoc:
  delegate sort!, to: children

  # Iterate over each result
  delegate each, to: results

  def initialize
    @root = true
  end

  # :nodoc:
  def initialize(@key : String, @context : Context(T))
    @priority = compute_priority
  end

  # :nodoc:
  def initialize(@key : String, payload : T? = nil)
    @priority = compute_priority
    payloads << payload if payload
  end

  # :nodoc:
  def <=>(other : self)
    result = kind <=> other.kind
    return result if result != 0
    other.priority <=> priority
  end

  # Adds a path to the tree.
  def add(path : String, payload : T)
    OptionalsParser.parse(path).each do |path|
      add_path path, payload
    end
  end

  # Finds the first matching result.
  def find(path)
    search(path).first? || Result(T).new
  end

  # :nodoc:
  def payloads?
    !payloads.empty?
  end

  # :nodoc:
  def placeholder?
    @root && key.empty? && payloads.empty?
  end

  # Lists all the results possible within the entire tree.
  def results
    ([] of Result(T)).tap do |ary|
      each_result do |result|
        ary << result
      end
    end
  end

  # Searchs the Tree and returns all results as an array.
  def search(path)
    ([] of Result(T)).tap do |results|
      search(path) do |result|
        results << result
      end
    end
  end

  # Searches the Tree and yields each result to the block.
  def search(path, &block : Result(T) -> _)
    search(path, Result(T).new, &block)
  end

  # Returns a string visualization of the Radix tree
  def visualize
    String.build do |io|
      visualize(0, io)
    end
  end

  # :nodoc:
  protected def add_path(path : String, payload : T)
    if placeholder?
      @key = path
      payloads << payload
      return self
    end

    analyzer = Analyzer.new(path: path, key: key)

    if analyzer.split_on_path?
      new_key = analyzer.remaining_path

      # Find a child key that matches the remaning path
      matching_child = children.find do |child|
        child.key[0]? == new_key[0]?
      end

      if matching_child
        if matching_child.key[0]? == ':' && new_key[0]? == ':' && !same_key?(new_key, matching_child.key)
          raise SharedKeyError.new(new_key, matching_child.key)
        end
        # add the path & payload within the child Tree
        matching_child.add_path new_key, payload
      else
        # add a new Tree with the remaining path
        children << Tree(T).new(new_key, payload)
      end

      # Reprioritze Tree
      sort!
    elsif analyzer.exact_match?
      payloads << payload
    elsif analyzer.split_on_key?
      # Readjust the key of this Tree
      self.key = analyzer.matched_key

      @context = Context.new(Tree(T).new(analyzer.remaining_key, @context))

      # Determine if the path continues
      if analyzer.remaining_path?
        # Add a new Tree with the remaining_path
        children << Tree(T).new(analyzer.remaining_path, payload)
      else
        # Insert the payload
        payloads << payload
      end

      # Reprioritze Tree
      sort!
    end
  end

  protected def dynamic?
    key[0] == ':' || key[0] == '*'
  end

  protected def dynamic_children?
    children.any? &.dynamic?
  end

  protected def dynamic_children
    children.select &.dynamic?
  end

  protected def each_result(result = Result(T).new, &block : Result(T) -> Void) : Void
    result = result.use self, &block if payloads?
    children.each do |child|
      result = result.track(self) do |outer_result|
        child.each_result(outer_result) do |inner_result|
          block.call(inner_result)
        end
      end
    end
  end

  protected def key=(@key)
    @kind = Kind::Normal # reset kind on change of key
    @priority = compute_priority
  end

  protected def search(path, result : Result(T), &block : Result(T) -> _) : Nil
    walker = Walker.new(path: path, key: key)

    walker.while_matching do
      case walker.key_char
      when '*'
        name = walker.key_slice(walker.key_pos + 1)
        value = walker.remaining_path
        result.params[name] = value unless name.empty?
        result = result.use(self, &block)
        break
      when ':'
        key_size = walker.key_param_size
        path_size = walker.path_param_size

        name = walker.key_slice(walker.key_pos + 1, key_size - 1)
        value = walker.path_slice(walker.path_pos, path_size)

        result.params[name] = value

        walker.key_pos += key_size
        walker.path_pos += path_size
      else
        walker.advance
      end
    end

    if walker.end?
      result = result.use(self, &block)
    end

    if walker.path_continues?
      if walker.path_trailing_slash_end?
        result = result.use(self, &block)
      end
      children.each do |child|
        remaining_path = walker.remaining_path
        if child.should_walk?(remaining_path)
          result = result.track self do |outer_result|
            child.search(remaining_path, outer_result, &block)
          end
        end
      end
    end

    if walker.key_continues?
      if walker.key_trailing_slash_end?
        result = result.use(self, &block)
      end

      if walker.catch_all?
        walker.next_key_char unless walker.key_char == '*'
        name = walker.key_slice(walker.key_pos + 1)

        result.params[name] = ""

        result = result.use(self, &block)
      end
    end

    if dynamic_children?
      dynamic_children.each do |child|
        if child.should_walk?(path)
          result = result.track self do |outer_result|
            child.search(path, outer_result, &block)
          end
        end
      end
    end
  end

  protected def shared_key?(path)
    Walker.new(path: path, key: key).shared_key?
  end

  protected def should_walk?(path)
    key[0]? == '*' || key[0]? == ':' || shared_key?(path)
  end

  protected def visualize(depth : Int32, io : IO)
    io.puts "  " * depth + "⌙ " + key + (payloads? ? " (payloads: #{payloads.size})" : "")
    children.each &.visualize(depth + 1, io)
  end

  private def compute_priority
    reader = Char::Reader.new(key)
    while reader.has_next?
      case reader.current_char
      when '*'
        @kind = Kind::Glob
        break
      when ':'
        @kind = Kind::Named
        break
      else
        reader.next_char
      end
    end
    reader.pos
  end

  private def same_key?(path, key)
    path_reader = Char::Reader.new(path)
    key_reader = Char::Reader.new(key)

    different = false

    while (path_reader.has_next? && path_reader.current_char != '/') &&
          (key_reader.has_next? && key_reader.current_char != '/')
      if path_reader.current_char != key_reader.current_char
        different = true
        break
      end

      path_reader.next_char
      key_reader.next_char
    end

    (!different) &&
      (path_reader.current_char == '/' || !path_reader.has_next?)
  end
end
