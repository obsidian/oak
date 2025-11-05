# :nodoc:
abstract struct Oak::Walker
  private getter bytesize : Int32
  private getter reader : Char::Reader

  delegate next_char, pos, current_char, has_next?, peek_next_char, to: reader

  def initialize(str : String)
    @bytesize = str.bytesize
    @reader = Char::Reader.new(str)
  end

  def pos=(i)
    reader.pos = i
  end

  def size_until_marker(skip_markers = 0)
    original_pos = pos

    # walk until we reach the marker or end
    while has_next?
      break if marker? && (skip_markers -= 1) < 0
      next_char
    end

    # Calc the size
    size = pos - original_pos

    # Reset the pos
    self.pos = original_pos

    # return the size
    return size
  end

  def marker_count
    original_pos = pos
    count = 0

    # count the markers until we reach the end
    while has_next?
      count += 1 if marker?
      next_char
    end

    # Reset the pos
    self.pos = original_pos

    count
  end

  def slice(*args)
    reader.string.unsafe_byte_slice(*args)
  end

  @[AlwaysInline]
  def trailing_slash_end?
    reader.pos + 1 == bytesize && current_char == '/'
  end

  @[AlwaysInline]
  def marker?
    current_char == '/'
  end

  def remaining
    slice pos
  end
end
