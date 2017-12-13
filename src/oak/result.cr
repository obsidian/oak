struct Oak::Result(T)
  @nodes = [] of Tree(T)
  getter params = {} of String => String
  getter leaves = [] of T

  def initialize
  end

  def initialize(@nodes, @params)
  end

  def leaf
    leaves.first
  end

  def found?
    @leaves.size > 0
  end

  def key
    String.build do |io|
      @nodes.each do |node|
        io << node.key
      end
    end
  end

  # alias for `#leaf`
  def payload
    leaf
  end

  def track(branch : Tree(T))
    @nodes << branch
    self
  end

  def track(branch : Tree(T), &block : Result(T) -> _)
    self.class.new(@nodes.dup, @params.dup).tap do
      block.call track(branch)
    end
  end

  def use(branch : Tree(T))
    track branch
    @leaves.replace branch.leaves
    self
  end

  def use(branch : Tree(T), &block : Result(T) -> _)
    self.class.new(@nodes.dup, @params.dup).tap do
      block.call use(branch)
    end
  end
end
