require "./node"

# :nodoc:
struct Oak::Context(T)
  CHILD_MAP_THRESHOLD = 10

  getter children = [] of Node(T)
  getter payloads = [] of T
  @child_map : Hash(Char, Node(T))? = nil

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

  # Find a child by first character, using hash map for large child sets
  def find_child(first_char : Char?)
    return nil if first_char.nil?

    if @child_map
      @child_map[first_char]?
    else
      children.find { |child| child.first_char == first_char }
    end
  end

  # Rebuild child map if threshold is exceeded
  def rebuild_child_map_if_needed
    if children.size >= CHILD_MAP_THRESHOLD && @child_map.nil?
      @child_map = {} of Char => Node(T)
      children.each do |child|
        @child_map.not_nil![child.first_char] = child
      end
    end
  end
end
