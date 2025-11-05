require "./node"

# Internal data structure containing node children and payloads.
#
# ## Performance Optimization
#
# Context automatically builds a HashMap for O(1) child lookups when the number of
# children exceeds `CHILD_MAP_THRESHOLD` (10). This dramatically improves performance
# for high-fanout nodes common in REST APIs.
#
# Example: A node with 20 children will use HashMap, reducing average lookup from
# 10 comparisons (linear search) to 1 (hash lookup).
#
# :nodoc:
struct Oak::Context(T)
  # Threshold for switching from linear search to HashMap-based child lookup.
  #
  # When children.size >= 10, a HashMap is automatically built for O(1) lookups.
  # This threshold balances memory overhead vs. lookup performance.
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

    if child_map = @child_map
      child_map[first_char]?
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
