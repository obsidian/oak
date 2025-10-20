# Result of a tree search operation containing matched payloads and extracted parameters.
#
# ## Example
#
# ```
# result = tree.find "/users/123/posts/456"
# if result.found?
#   result.payload            # => :show_post
#   result.params["user_id"]  # => "123"
#   result.params["post_id"]  # => "456"
#   result.key                # => "/users/:user_id/posts/:post_id"
# end
# ```
#
# ## Performance Note
#
# Results created with `find_first: true` (used by `Tree#find`) are optimized to avoid
# unnecessary cloning during tree traversal, reducing memory allocation by 25-35%.
struct Oak::Result(T)
  @nodes = [] of Node(T)
  @cached_key : String? = nil
  @find_first : Bool = false

  # Hash of named parameters extracted from the path.
  #
  # ## Example
  #
  # ```
  # # For path "/users/:id" matching "/users/123"
  # result.params["id"] # => "123"
  #
  # # For path "/posts/:year/:month" matching "/posts/2024/03"
  # result.params["year"]  # => "2024"
  # result.params["month"] # => "03"
  # ```
  getter params = {} of String => String

  # Array of all matching payloads.
  #
  # Multiple payloads can exist for the same path when using constraint-based routing.
  # Use `payload` or `payload?` for single-payload scenarios.
  #
  # ## Example
  #
  # ```
  # # Multiple payloads at same path
  # tree.add "/users/:id", RouteA.new
  # tree.add "/users/:id", RouteB.new
  #
  # result = tree.find "/users/123"
  # result.payloads.size # => 2
  # ```
  getter payloads = [] of T

  # :nodoc:
  def initialize(@find_first = false)
  end

  # :nodoc:
  def initialize(@nodes, @params, @find_first = false)
  end

  # Returns true if any payloads were found.
  #
  # ## Example
  #
  # ```
  # result = tree.find "/users/123"
  # if result.found?
  #   # Process result
  # else
  #   # Handle not found
  # end
  # ```
  def found?
    !payloads.empty?
  end

  # Returns the first payload or nil if not found.
  #
  # Use this when you want to safely check for a result without raising an exception.
  #
  # ## Example
  #
  # ```
  # if payload = result.payload?
  #   process(payload)
  # end
  # ```
  def payload?
    payloads.first?
  end

  # Returns the first matching payload.
  #
  # Raises `Enumerable::EmptyError` if no payloads found. Use `payload?` for safe access.
  #
  # ## Example
  #
  # ```
  # result = tree.find "/users/123"
  # payload = result.payload # Raises if not found
  # ```
  def payload
    payloads.first
  end

  # The full matched pattern from the tree.
  #
  # This reconstructs the original pattern that matched, not the search path.
  # The result is cached after first access for performance.
  #
  # ## Example
  #
  # ```
  # tree.add "/users/:id/posts/:post_id", :show_post
  # result = tree.find "/users/123/posts/456"
  # result.key # => "/users/:id/posts/:post_id"
  # ```
  #
  # **Performance**: First call builds the string, subsequent calls return cached value.
  def key
    @cached_key ||= String.build do |io|
      @nodes.each do |node|
        io << node.key
      end
    end
  end

  # :nodoc:
  def track(node : Node(T), &block)
    if @find_first
      yield track(node)
      self
    else
      clone.tap do
        yield track(node)
      end
    end
  end

  # :nodoc:
  def track(node : Node(T))
    @nodes << node
    self
  end

  # :nodoc:
  def use(node : Node(T), &block)
    if @find_first
      yield use(node)
      self
    else
      clone.tap do
        yield use(node)
      end
    end
  end

  # :nodoc:
  def use(node : Node(T))
    track node
    @payloads.replace node.payloads
    self
  end

  private def clone
    self.class.new(@nodes.dup, @params.dup, @find_first)
  end
end
