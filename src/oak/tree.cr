require "./result"
require "./searcher"

# A high-performance radix tree (compressed trie) for path matching.
#
# Oak::Tree is optimized for HTTP routing and similar use cases where:
# - Fast lookups are critical (O(k) where k = path length)
# - Memory efficiency matters
# - Type safety is required
#
# ## Example
#
# ```
# tree = Oak::Tree(Symbol).new
# tree.add "/users/:id", :show_user
# tree.add "/users/:id/posts", :user_posts
#
# result = tree.find "/users/123/posts"
# result.payload      # => :user_posts
# result.params["id"] # => "123"
# ```
#
# ## Performance
#
# - 30-50% faster search than baseline implementations
# - 40-60% less memory allocation for single-match lookups
# - Automatic optimization for high-fanout nodes (>10 children)
#
# See PERFORMANCE.md for detailed benchmarks.
struct Oak::Tree(T)
  @root = Oak::Node(T).new

  # Adds a path and its associated payload to the tree.
  #
  # Supports:
  # - Static paths: `/users/new`
  # - Named parameters: `/users/:id`
  # - Glob wildcards: `/search/*query`
  # - Optional segments: `/products(/free)/:id`
  #
  # ## Example
  #
  # ```
  # tree.add "/users/:id", :show_user
  # tree.add "/posts/:year/:month/:slug", :show_post
  # tree.add "/search/*query", :search
  # tree.add "/products(/free)/:id", :show_product
  # ```
  #
  # Multiple payloads can be added to the same path for constraint-based routing.
  def add(path, payload)
    @root.add(path, payload)
  end

  # Finds the first matching result for the given path.
  #
  # This is optimized for single-match lookups (40-60% less allocation than `search().first?`).
  # Use this when you only need one result.
  #
  # ## Example
  #
  # ```
  # result = tree.find "/users/123"
  # if result.found?
  #   puts result.payload      # First matching payload
  #   puts result.params["id"] # => "123"
  # end
  # ```
  #
  # Returns an empty Result if no match found (check with `result.found?`).
  def find(path) : Result(T)
    found_result : Result(T)? = nil
    Searcher(T).search(@root, path, Result(T).new(find_first: true)) do |r|
      found_result = r
      next
    end

    (found_result || Result(T).new).as(Result(T))
  end

  # Searches the tree and returns all matching results as an array.
  #
  # Use when you need multiple results (e.g., constraint-based routing).
  # For single matches, prefer `find()` for better performance.
  #
  # ## Example
  #
  # ```
  # results = tree.search "/users/123"
  # results.each do |result|
  #   puts result.payload
  # end
  # ```
  def search(path)
    ([] of Result(T)).tap do |results|
      search(path) do |result|
        results << result
      end
    end
  end

  # Searches the tree and yields each matching result to the block.
  #
  # This is more efficient than `search(path).each` as it doesn't allocate an intermediate array.
  #
  # ## Example
  #
  # ```
  # tree.search("/users/123") do |result|
  #   if route = result.payloads.find(&.matches?(request))
  #     route.call(context)
  #     break
  #   end
  # end
  # ```
  def search(path, &block : Result(T) -> _)
    Searcher(T).search(@root, path, Result(T).new, &block)
  end

  # Returns a visual representation of the tree structure for debugging.
  #
  # ## Example
  #
  # ```
  # puts tree.visualize
  # # ⌙
  # #   ⌙ /users (payloads: 1)
  # #     ⌙ /:id (payloads: 1)
  # #       ⌙ /posts (payloads: 1)
  # ```
  def visualize
    @root.visualize
  end
end
