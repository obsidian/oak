require "./result"

class Oak::Node(T)
  # :nodoc:
  struct Context(T)
    getter children = [] of Node(T)
    getter payloads = [] of T

    def initialize(child : Node(T)? = nil)
      children << child if child
    end

    # Returns true of there are associated payloads
    def payloads?
      !payloads.empty?
    end

    # Returns true of there are associated children
    def children?
      !children.empty?
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

  include Comparable(self)

  @root = false

  # The key of the current tree child
  getter key : String = ""
  protected getter priority : Int32 = 0
  protected getter context = Context(T).new
  protected getter kind = Kind::Normal

  # :nodoc:
  delegate payloads, payloads?, payload, payload?, children, children?, to: @context

  # :nodoc:
  delegate normal?, named?, glob?, to: kind
  # :nodoc:
  delegate sort!, to: children

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
    OptionalsParser.parse(path).map do |path|
      add_path path, payload
    end
  end

  # :nodoc:
  private def placeholder?
    @root && key.empty? && payloads.empty? && children.empty?
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

    if !key.empty? && analyzer.path_reader_at_zero_pos?
      @context = Context.new(Node(T).new(@key, @context))
      @key = ""
    end

    node = if analyzer.split_on_path?
      new_key = analyzer.remaining_path

      # Find a child key that matches the remaning path
      matching_child = children.find do |child|
        child.key[0]? == new_key[0]?
      end

      if matching_child
        if matching_child.key[0]? == ':' && new_key[0]? == ':' && !same_key?(new_key, matching_child.key)
          raise SharedKeyError.new(new_key, matching_child.key)
        end
        # add the path & payload within the child Node
        matching_child.add_path new_key, payload
      else
        # add a new Node with the remaining path
        Node(T).new(new_key, payload).tap { |node| children << node }
      end
    elsif analyzer.exact_match?
      payloads << payload
      self
    elsif analyzer.split_on_key?
      # Readjust the key of this Node
      self.key = analyzer.matched_key

      Node(T).new(analyzer.remaining_key, @context).tap do |node|
        @context = Context.new(node)

        # Determine if the path continues
        if analyzer.remaining_path?
          # Add a new Node with the remaining_path
          children << Node(T).new(analyzer.remaining_path, payload)
        else
          # Insert the payload
          payloads << payload
        end
      end
    end

    sort!
    node || self
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

  protected def key=(@key)
    @kind = Kind::Normal # reset kind on change of key
    @priority = compute_priority
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
