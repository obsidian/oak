class Oak::Tree(T)
  struct Context(T)
    getter branches = [] of Tree(T)
    getter leaves = [] of T

    def initialize(branch : Tree(T)? = nil)
      branches << branch if branch
    end
  end

  class SharedKeyError < Exception
      def initialize(new_key, existing_key)
        super("Tried to place key '#{new_key}' at same level as '#{existing_key}'")
      end
    end

  enum Kind : UInt8
    Normal
    Named
    Glob
  end

  include Enumerable(Result(T))
  include Comparable(self)

  @root = false
  getter context = Context(T).new
  getter key : String = ""
  getter priority : Int32 = 0
  protected getter kind = Kind::Normal

  delegate branches, leaves, to: @context
  delegate normal?, named?, glob?, to: kind
  delegate sort!, to: branches
  delegate each, to: results

  def initialize
    @root = true
  end

  def initialize(@key : String, @context : Context(T))
    @priority = compute_priority
  end

  def initialize(@key : String, payload : T? = nil)
    @priority = compute_priority
    leaves << payload if payload
  end

  def <=>(other : self)
    result = kind <=> other.kind
    return result if result != 0
    other.priority <=> priority
  end

  def add(path : String, payload : T)
    OptionalsParser.parse(path).each do |path|
      add_path path, payload
    end
  end

  def find(path)
    search(path).first?
  end

  def leaves?
    !leaves.empty?
  end

  def placeholder?
    @root && key.empty? && leaves.empty?
  end

  def results
    ([] of Result(T)).tap do |ary|
      each_result do |result|
        ary << result
      end
    end
  end

  def search(path)
    ([] of Result(T)).tap do |results|
      search(path) do |result|
        results << result
      end
    end
  end

  def search(path, &block : Result(T) -> _)
    search(path, Result(T).new, &block)
  end

  def visualize
    String.build do |io|
      visualize(0, io)
    end
  end

  protected def add_path(path : String, payload : T)
    if placeholder?
      @key = path
      leaves << payload
      return self
    end

    analyzer = Analyzer.new(path: path, key: key)

    if analyzer.split_on_path?
      new_key = analyzer.remaining_path

      # Find a child key that matches the remaning path
      matching_child = branches.find do |branch|
        branch.key[0]? == new_key[0]?
      end

      if matching_child
        if matching_child.key[0]? == ':' && new_key[0]? == ':' && !same_key?(new_key, matching_child.key)
          raise SharedKeyError.new(new_key, matching_child.key)
        end
        # add the path & payload within the child Tree
        matching_child.add_path new_key, payload
      else
        # add a new Tree with the remaining path
        branches << Tree(T).new(new_key, payload)
      end

      # Reprioritze Tree
      sort!
    elsif analyzer.exact_match?
      leaves << payload
    elsif analyzer.split_on_key?
      # Readjust the key of this Tree
      self.key = analyzer.matched_key

      @context = Context.new(Tree(T).new(analyzer.remaining_key, @context))

      # Determine if the path continues
      if analyzer.remaining_path?
        # Add a new Tree with the remaining_path
        branches << Tree(T).new(analyzer.remaining_path, payload)
      else
        # Insert the payload
        leaves << payload
      end

      # Reprioritze Tree
      sort!
    end
  end

  protected def dynamic?
    key[0] == ':' || key[0] == '*'
  end

  protected def dynamic_branches?
    branches.any? &.dynamic?
  end

  protected def dynamic_branches
    branches.select &.dynamic?
  end

  protected def each_result(result = Result(T).new, &block : Result(T) -> Void) : Void
    result = result.use self, &block if leaves?
    branches.each do |branch|
      result = result.track(self) do |outer_result|
        branch.each_result(outer_result) do |inner_result|
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
    if @root && (path.bytesize == key.bytesize && path == key) && leaves?
      result = result.use(self, &block)
    end

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
      branches.each do |branch|
        remaining_path = walker.remaining_path
        if branch.should_walk?(remaining_path)
          result = result.track self do |outer_result|
            branch.search(remaining_path, outer_result, &block)
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

    if dynamic_branches?
      dynamic_branches.each do |branch|
        if branch.should_walk?(path)
          result = result.track self do |outer_result|
            branch.search(path, outer_result, &block)
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
    io.puts "  " * depth + "⌙ " + key + (leaves? ? " (leaves: #{leaves.size})" : "")
    branches.each &.visualize(depth + 1, io)
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
