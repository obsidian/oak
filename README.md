# Oak
Another [radix tree](https://en.wikipedia.org/wiki/Radix_tree) implementation for crystal-lang

[![Build Status](https://img.shields.io/travis/obsidian/oak/master.svg)](https://travis-ci.org/obsidian/oak)
[![Latest Release](https://img.shields.io/github/release/obsidian/oak.svg)](https://github.com/obsidian/oak/releases)

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  oak:
    github: obsidian/oak
```

## Usage

### Building Trees

You can associate one or more *leaves* with each path added to the tree:

```crystal
require "oak"

tree = Oak::Tree(Symbol).new
tree.add "/products", :products
tree.add "/products/featured", :featured

results = tree.search "/products/featured"

if result = results.first?
  puts result.leaf # => :featured
end
```

The types allowed for a leaf are defined on Tree definition:

```crystal
tree = Oak::Tree(Symbol).new

# Good, since Symbol is allowed as payload
tree.add "/", :root

# Compilation error, Int32 is not allowed
tree.add "/meaning-of-life", 42
```

Can combine multiple types if needed:

```crystal
tree = Oak::Tree(Int32 | String | Symbol).new

tree.add "/", :root
tree.add "/meaning-of-life", 42
tree.add "/hello", "world"
```

### Lookup and placeholders

You can also extract values from placeholders (as named or globbed segments):

```crystal
tree.add "/products/:id", :product

result = tree.find "/products/1234"

if result
  puts result.params["id"]? # => "1234"
end
```

Please see `Oak::Tree#add` documentation for more usage examples.

## Optionals

Oak has the ability to add optional paths, i.e. `foo(/bar)/:id`, which will expand
into two routes: `foo/bar/:id` and `foo/:id`. In the following example, both results
will match and return the same leaf.

```crystal
tree.add "/products(/free)/:id", :product

if result = tree.find "/products/1234"
  puts result.params["id"]? # => "1234"
  puts result.leaf # => :product
end

if result = tree.find "/products/free/1234"
  puts result.params["id"]? # => "1234"
  puts result.leaf # => :product
end
```

## Caveats

### Multiple results

Due the the dynamic nature of this radix tree, and to allow for a more flexible
experience for the implementer, the `.search` method will return a list of results.
Alternatively, you can interact with the results by providing a block.

```crystal
matching_leaf = nil
@tree.search(path) do |result|
  unless matching_leaf
    context.request.path_params = result.params
    matching_leaf = result.leaves.find do |leaf|
      leaf.matches_constraints? context.request
    end
    matching_leaf.try &.call(context)
  end
end
```

### Multiple Leaves

In order to allow for a more flexible experience for the implementer, this
implementation of radix will not error if a multiple leaves are added at the
same path/key. You can either call the `.leaf` method to grab the first leaf,
or you can use the `.leaves` method, which will return all the leaves.

### Shared Keys

When designing and adding *paths* to a Tree, please consider that two different
named parameters cannot share the same level:

```crystal
tree.add "/", :root
tree.add "/:post", :post
tree.add "/:category/:post", :category_post # => Radix::Tree::SharedKeyError
```

This is because different named parameters at the same level will result in
incorrect `params` when lookup is performed, and sometimes the value for
`post` or `category` parameters will not be stored as expected.

To avoid this issue, usage of explicit keys that differentiate each path is
recommended.

For example, following a good SEO practice will be consider `/:post` as
absolute permalink for the post and have a list of categories which links to
a permalink of the posts under that category:

```crystal
tree.add "/", :root
tree.add "/:post", :post                    # this is post permalink
tree.add "/categories", :categories         # list of categories
tree.add "/categories/:category", :category # listing of posts under each category
```
## Roadmap

* [X] Support multiple leaves at the same level in the tree.
* [X] Return multiple matches when searching the tree.
* [X] Support optionals in the key path.
* [ ] Overcome shared key caveat.

## Implementation

This project has been inspired and adapted from:
[luislavena](https://github.com/luislavena/radix)

## Contributing

1. Fork it ( https://github.com/obsidian/oak/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Jason Waldrip](https://github.com/jwaldrip) - creator, maintainer
