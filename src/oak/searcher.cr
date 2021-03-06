require "./key_walker"
require "./path_walker"
require "./node"

# :nodoc:
struct Oak::Searcher(T)
  @key : KeyWalker
  @path : PathWalker
  @node : Node(T)
  private getter! result : Result(T)

  def self.search(node, path, result : Result(T), &block : Result(T) -> _)
    new(path: path, result: result, node: node).search(&block)
  end

  def initialize(*, path : String, @result = nil, @node)
    @key = KeyWalker.new(node.key)
    @path = PathWalker.new(path)
  end

  def shared_key?
    return false if (@path.current_char != @key.current_char) && @key.marker?

    different = false

    while (@path.has_next? && @path.current_char != '/') && (@key.has_next? && !@key.marker?)
      if @path.current_char != @key.current_char
        different = true
        break
      end

      advance
    end

    !different && (!@key.has_next? || @key.marker?)
  end

  protected def search(&block : Result(T) -> _) : Nil
    walk!

    # If ended, extract the result
    if end?
      @result = result.use(@node, &block)
    elsif @path.has_next?
      @result = result.use(@node, &block) if @path.trailing_slash_end?
      @node.children.each do |child|
        remaining_path = @path.remaining
        if child.should_walk?(remaining_path)
          @result = result.track @node do |outer_result|
            self.class.search(child, remaining_path, outer_result, &block)
          end
        end
      end
    elsif @key.has_next?
      if @key.trailing_slash_end?
        @result = result.use(@node, &block)
      elsif @key.catch_all?
        @key.next_char unless @key.current_char == '*'
        result.params[@key.name] = ""
        @result = result.use(@node, &block)
      end
    end
  end

  private def walk!
    while_matching do
      case @key.current_char
      when '*'
        name = @key.name
        value = @path.value(@key.marker_count)
        result.params[name] = value unless name.empty?
      when ':'
        result.params[@key.name] = @path.value
      else
        advance
      end
    end
  end

  private def advance
    @key.next_char
    @path.next_char
  end

  private def end?
    !@path.has_next? && !@key.has_next?
  end

  private def matching_chars?
    @path.current_char == @key.current_char
  end

  private def while_matching
    while @key.has_next? && @path.has_next? && (@key.dynamic_char? || matching_chars?)
      yield
    end
  end
end
