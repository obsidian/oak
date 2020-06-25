class Oak::Result(T)
  @nodes = [] of Node(T)

  # The named params found in the result.
  getter params = {} of String => String

  # The matching payloads of the result.
  getter payloads = [] of T

  def initialize
  end

  def initialize(@nodes, @params)
  end

  def found?
    !payloads.empty?
  end

  def payload?
    payloads.first?
  end

  # Returns the first payload in the result.
  def payload
    payloads.first
  end

  # The full resulting key.
  def key
    String.build do |io|
      @nodes.each do |node|
        io << node.key
      end
    end
  end

  # :nodoc:
  def track(node : Node(T))
    @nodes << node
    self
  end

  # :nodoc:
  def track(node : Node(T))
    clone.tap do
      yield track(node)
    end
  end

  # :nodoc:
  def use(node : Node(T))
    track node
    @payloads.replace node.payloads
    self
  end

  # :nodoc:
  def use(node : Node(T))
    clone.tap do
      yield use(node)
    end
  end

  private def clone
    self.class.new(@nodes.dup, @params.dup)
  end
end
