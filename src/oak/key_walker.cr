require "./walker"

# :nodoc:
struct Oak::KeyWalker < Oak::Walker
  @[AlwaysInline]
  def dynamic_char?
    {'*', ':'}.includes? reader.current_char
  end

  def name
    next_char
    size = size_until_marker
    name = slice(pos, size)
    self.pos += size
    name
  end

  def marker?
    super || dynamic_char?
  end

  def catch_all?
    reader.pos < bytesize && (
      (current_char == '/' && peek_next_char == '*') || current_char == '*'
    )
  end
end
