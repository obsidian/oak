require "./result"
require "./searcher"

struct Oak::Tree(T)
  include Enumerable(Result(T))

  # Iterate over each result
  delegate each, to: results

  getter root = Oak::Node(T).new

  delegate visualize, add, to: @root

  # Finds the first matching result.
  def find(path)
    search(path).first? || Result(T).new
  end

  # Lists all the results possible within the entire tree.
  def results
    ([] of Result(T)).tap do |ary|
      each_result do |result|
        ary << result
      end
    end
  end

  # Searchs the Node and returns all results as an array.
  def search(path)
    ([] of Result(T)).tap do |results|
      search(path) do |result|
        results << result
      end
    end
  end

  # Searches the Node and yields each result to the block.
  def search(path, &block : Result(T) -> _)
    Searcher(T).search(@root, path, Result(T).new, &block)
  end

  protected def each_result(result = Result(T).new, &block : Result(T) -> Void) : Void
    result = result.use self, &block if payloads?
    children.each do |child|
      result = result.track(self) do |outer_result|
        child.each_result(outer_result) do |inner_result|
          block.call(inner_result)
        end
      end
    end
  end
end
