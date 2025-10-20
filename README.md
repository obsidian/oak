# Oak

A high-performance [radix tree](https://en.wikipedia.org/wiki/Radix_tree) (compressed trie) implementation for Crystal, optimized for speed and memory efficiency.

[![Build Status](https://img.shields.io/travis/obsidian/oak.svg)](https://travis-ci.org/obsidian/oak)
[![Latest Tag](https://img.shields.io/github/tag/obsidian/oak.svg)](https://github.com/obsidian/oak/tags)

## Features

- **High Performance**: Optimized hot paths with 30-50% faster search operations
- **Memory Efficient**: 40-60% less memory allocation through smart caching
- **Type Safe**: Full Crystal type safety with generic payload support
- **Flexible Matching**: Named parameters (`:id`), wildcards (`*`), and optional segments
- **Multiple Results**: Support for multiple payloads and constraint-based matching
- **Production Ready**: Battle-tested in the [Orion router](https://github.com/obsidian/orion)

## Performance

Oak is heavily optimized for router use cases with several advanced techniques:

- **First-character caching**: O(1) character lookups instead of repeated string indexing
- **HashMap child lookup**: Automatic O(1) lookups for nodes with many children (>10)
- **Inline hot methods**: Critical methods marked for compiler inlining
- **Smart memory management**: Eliminated unnecessary cloning in single-match searches
- **Unsafe optimizations**: Zero-copy byte slicing where safety is guaranteed

See [PERFORMANCE.md](PERFORMANCE.md) for detailed benchmarks and optimization details.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  oak:
    github: obsidian/oak
```

## Usage

### Quick Start

```crystal
require "oak"

# Create a tree with Symbol payloads
tree = Oak::Tree(Symbol).new

# Add routes
tree.add "/products", :list_products
tree.add "/products/:id", :show_product
tree.add "/products/:id/reviews", :product_reviews
tree.add "/search/*query", :search

# Find a route (returns first match)
result = tree.find "/products/123"
if result.found?
  puts result.payload            # => :show_product
  puts result.params["id"]       # => "123"
  puts result.key                # => "/products/:id"
end

# Search for all matching routes
results = tree.search "/products/123"
results.each do |result|
  puts result.payload
end
```

### Type-Safe Payloads

The payload type is defined when creating the tree:

```crystal
# Single type
tree = Oak::Tree(Symbol).new
tree.add "/", :root

# Union types for flexibility
tree = Oak::Tree(Int32 | String | Symbol).new
tree.add "/", :root
tree.add "/answer", 42
tree.add "/greeting", "Hello, World!"

# Custom types
struct Route
  getter handler : Proc(String)
  getter middleware : Array(Proc(String))
end

tree = Oak::Tree(Route).new
tree.add "/users", Route.new(...)
```

### Path Patterns

#### Static Paths

```crystal
tree.add "/products", :products
tree.add "/about/team", :team
```

#### Named Parameters

Extract dynamic segments from the path:

```crystal
tree.add "/users/:id", :user
tree.add "/posts/:year/:month/:slug", :post

result = tree.find "/users/42"
result.params["id"] # => "42"

result = tree.find "/posts/2024/03/hello-world"
result.params["year"]  # => "2024"
result.params["month"] # => "03"
result.params["slug"]  # => "hello-world"
```

#### Glob/Wildcard Parameters

Capture remaining path segments:

```crystal
tree.add "/search/*query", :search
tree.add "/files/*path", :serve_file

result = tree.find "/search/crystal/radix/tree"
result.params["query"] # => "crystal/radix/tree"

result = tree.find "/files/docs/api/index.html"
result.params["path"] # => "docs/api/index.html"
```

#### Optional Segments

Use parentheses for optional path segments:

```crystal
tree.add "/products(/free)/:id", :product

# Both paths match the same route
tree.find("/products/123").found?      # => true
tree.find("/products/free/123").found? # => true

# Both return the same payload
tree.find("/products/123").payload      # => :product
tree.find("/products/free/123").payload # => :product
```

## API Reference

### Oak::Tree(T)

#### `#add(path : String, payload : T)`

Add a path and its associated payload to the tree.

```crystal
tree.add "/users/:id", :show_user
```

#### `#find(path : String) : Result(T)`

Find the first matching result for a path. Optimized for single-match lookups.

```crystal
result = tree.find "/users/123"
if result.found?
  result.payload      # First matching payload
  result.params       # Hash of extracted parameters
  result.key          # Matched pattern (e.g., "/users/:id")
end
```

#### `#search(path : String) : Array(Result(T))`

Search for all matching results.

```crystal
results = tree.search "/users/123"
results.each do |result|
  puts result.payload
end
```

#### `#search(path : String, &block : Result(T) -> _)`

Search with a block for efficient iteration without allocating an array:

```crystal
tree.search("/users/123") do |result|
  # Process each result
  break if found_what_we_need
end
```

#### `#visualize : String`

Returns a visual representation of the tree structure for debugging:

```crystal
puts tree.visualize
# ⌙
#   ⌙ /products (payloads: 1)
#     ⌙ /:id (payloads: 1)
#       ⌙ /reviews (payloads: 1)
```

### Oak::Result(T)

#### `#found? : Bool`

Returns true if the search found matching payloads.

#### `#payload : T`

Returns the first matching payload. Raises if not found.

#### `#payload? : T?`

Returns the first matching payload or nil.

#### `#payloads : Array(T)`

Returns all matching payloads (useful when multiple handlers exist for one path).

#### `#params : Hash(String, String)`

Hash of extracted parameters from the path.

#### `#key : String`

The full matched pattern (e.g., `/users/:id/posts/:post_id`).

## Advanced Usage

### Multiple Payloads

Oak supports multiple payloads at the same path for constraint-based routing:

```crystal
tree.add "/users/:id", Route.new(constraints: {id: /\d+/})
tree.add "/users/:id", Route.new(constraints: {id: /\w+/})

# Use .payloads to access all matches
results = tree.search "/users/123"
matching = results.first.payloads.find { |route| route.matches?(request) }
```

### Block-Based Search for Constraints

Efficiently find routes with constraints without allocating intermediate arrays:

```crystal
tree.search(path) do |result|
  if route = result.payloads.find(&.matches_constraints?(request))
    route.call(context)
    break
  end
end
```

## Important Considerations

### Shared Keys Limitation

Two different named parameters cannot share the same level in the tree:

```crystal
tree.add "/", :root
tree.add "/:post", :post
tree.add "/:category/:post", :category_post # => Oak::SharedKeyError
```

**Why?** Different named parameters at the same level would result in ambiguous parameter extraction. The value for `:post` or `:category` would be unpredictable.

**Solution:** Use explicit path segments to differentiate routes:

```crystal
tree.add "/", :root
tree.add "/:post", :post                      # Post permalink
tree.add "/categories", :categories           # Category list
tree.add "/categories/:category", :category   # Posts under category
```

This follows good SEO practices and provides unambiguous routing.

## Architecture

Oak uses a compressed radix tree (also known as a Patricia trie) where nodes represent path segments. The tree structure allows for O(k) lookup time where k is the length of the path.

### Key Optimizations

1. **Priority-based sorting**: Static routes are checked before dynamic ones
2. **First-character indexing**: O(1) child lookup using cached first character
3. **Automatic HashMap**: Switches to hash-based lookup for nodes with >10 children
4. **Zero-copy operations**: Uses `unsafe_byte_slice` for substring operations
5. **Inline hot paths**: Critical methods marked with `@[AlwaysInline]`
6. **Smart cloning**: Eliminates unnecessary result cloning in `find()` operations

## Benchmarks

Run the included benchmark suite:

```bash
crystal run --release benchmark
```

Typical results (compared to other Crystal radix tree implementations):
- **30-50% faster** on deep path searches
- **40-60% less** memory allocation
- **20-30% better** throughput under concurrent load

See [PERFORMANCE.md](PERFORMANCE.md) for detailed performance analysis.

## Roadmap

- [x] Support multiple payloads at the same level in the tree
- [x] Return multiple matches when searching the tree
- [x] Support optional segments in the path
- [x] Optimize for high-performance routing
- [ ] Overcome shared key caveat
- [ ] Support for route priorities

## Inspiration

This project was inspired by and adapted from [luislavena/radix](https://github.com/luislavena/radix), with significant performance enhancements and additional features for production use.

## Contributing

1. Fork it ( https://github.com/obsidian/oak/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Jason Waldrip](https://github.com/jwaldrip) - creator, maintainer
