require "./node"

# :nodoc:
struct Oak::Context(T)
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
