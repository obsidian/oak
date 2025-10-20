require "./result"
require "./searcher"

struct Oak::Tree(T)
  @root = Oak::Node(T).new

  # Add a path to the tree.
  def add(path, payload)
    @root.add(path, payload)
  end

  # Find the first matching result in the tree.
  def find(path)
    result = nil
    Searcher(T).search(@root, path, Result(T).new(find_first: true)) do |r|
      result = r
      break
    end
    result || Result(T).new
  end

  # Search the tree and return all results as an array.
  def search(path)
    ([] of Result(T)).tap do |results|
      search(path) do |result|
        results << result
      end
    end
  end

  # Search the tree and yield each result to the block.
  def search(path, &block : Result(T) -> _)
    Searcher(T).search(@root, path, Result(T).new, &block)
  end

  # Visualize the radix tree structure.
  def visualize
    @root.visualize
  end
end
