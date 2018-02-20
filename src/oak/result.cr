struct Oak::Result(T)
  @nodes = [] of Tree(T)

  # The named params found in the result.
  getter params = {} of String => String

  # The matching leaves of the result.
  getter leaves = [] of T

  def initialize
  end

  def initialize(@nodes, @params)
  end

  def found?
    !leaves.empty?
  end

  # Returns the first leaf in the result.
  def leaf
    leaves.first
  end

  # The full resulting key.
  def key
    String.build do |io|
      @nodes.each do |node|
        io << node.key
      end
    end
  end

  # alias for `#leaf`.
  def payload
    leaf
  end

  # :nodoc:
  def track(branch : Tree(T))
    @nodes << branch
    self
  end

  # :nodoc:
  def track(branch : Tree(T), &block : Result(T) -> _)
    self.class.new(@nodes.dup, @params.dup).tap do
      block.call track(branch)
    end
  end

  # :nodoc:
  def use(branch : Tree(T))
    track branch
    @leaves.replace branch.leaves
    self
  end

  # :nodoc:
  def use(branch : Tree(T), &block : Result(T) -> _)
    self.class.new(@nodes.dup, @params.dup).tap do
      block.call use(branch)
    end
  end
end
