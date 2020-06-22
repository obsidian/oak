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
    search(@root, path, Result(T).new, &block)
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

  protected def search(node, path, result : Result(T), &block : Result(T) -> _) : Nil
    walker = Walker.new(path: path, key: node.key)

    walker.while_matching do
      case walker.key_char
      when '*'
        name = walker.key_slice(walker.key_pos + 1)
        value = walker.remaining_path
        result.params[name] = value unless name.empty?
        result = result.use(node, &block)
        break
      when ':'
        key_size = walker.key_param_size
        path_size = walker.path_param_size

        name = walker.key_slice(walker.key_pos + 1, key_size - 1)
        value = walker.path_slice(walker.path_pos, path_size)

        result.params[name] = value

        walker.key_pos += key_size
        walker.path_pos += path_size
      else
        walker.advance
      end
    end

    if walker.end?
      result = result.use(node, &block)
    end

    if walker.path_continues?
      if walker.path_trailing_slash_end?
        result = result.use(node, &block)
      end
      node.children.each do |child|
        remaining_path = walker.remaining_path
        if child.should_walk?(remaining_path)
          result = result.track node do |outer_result|
            search(child, remaining_path, outer_result, &block)
          end
        end
      end
    end

    if walker.key_continues?
      if walker.key_trailing_slash_end?
        result = result.use(node, &block)
      end

      if walker.catch_all?
        walker.next_key_char unless walker.key_char == '*'
        name = walker.key_slice(walker.key_pos + 1)

        result.params[name] = ""

        result = result.use(node, &block)
      end
    end
  end
end
