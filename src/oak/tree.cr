struct Oak::Tree(T)
  include Enumerable(Result(T))

  # Iterate over each result
  delegate each, to: results

  @root = Oak::Node(T).new

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
  def search(path)
    search(@root, path, Result(T).new) do |r|
      yield r
    end
  end

  protected def each_result(result = Result(T).new) : Void
    if payloads?
      result = result.use(self) do |r|
        yield r
      end
    end

    children.each do |child|
      result = result.track(self) do |outer_result|
        child.each_result(outer_result) do |inner_result|
          yield inner_result
        end
      end
    end
  end

  protected def search(node, path, result : Result(T)) : Nil
    walker = Walker.new(path: path, key: node.key)

    walker.while_matching do
      case walker.key_char
      when '*'
        name = walker.key_slice(walker.key_pos + 1)
        value = walker.remaining_path
        result.params[name] = value unless name.empty?
        result = result.use(node) do |r|
          yield r
        end
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
      result = result.use(node) do |r|
        yield r
      end
    end

    if walker.path_continues?
      if walker.path_trailing_slash_end?
        result = result.use(node) do |r|
          yield r
        end
      end
      walk_children(node, node.dynamic_children, walker.remaining_path, result) do |r|
        yield r
      end
    end

    if walker.key_continues?
      if walker.key_trailing_slash_end?
        result = result.use(node) do |r|
          yield r
        end
      end

      if walker.catch_all?
        walker.next_key_char unless walker.key_char == '*'
        name = walker.key_slice(walker.key_pos + 1)

        result.params[name] = ""

        result = result.use(node) do |r|
          yield r
        end
      end
    end

    if node.dynamic_children?
      result = walk_children(node, node.dynamic_children, path, result) do |r|
        yield r
      end
    end
  end

  def walk_children(node, children, path, result)
    children.each do |child|
      if child.should_walk?(path)
        result = result.track node do |outer_result|
          search(child, path, outer_result) do |r|
            yield r
          end
        end
      end
    end
    result
  end
end
