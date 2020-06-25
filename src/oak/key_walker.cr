require "./walker"

struct Oak::KeyWalker < Oak::Walker
  def dynamic_char?
    {'*', ':'}.includes? reader.current_char
  end

  def name
    next_char
    size = size_until_marker
    slice(pos, size).tap do |name|
      self.pos += size
    end
  end

  def marker?
    super || dynamic_char?
  end

  def catch_all?
    reader.pos < bytesize && (
      (current_char == '/' && peek_char == '*') || current_char == '*'
    )
  end
end
