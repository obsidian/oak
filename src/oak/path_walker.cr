require "./walker"

struct Oak::PathWalker < Oak::Walker
  def dynamic_char?
    {'*', ':', '(', ')'}.includes? current_char
  end

  def marker?
    super || dynamic_char?
  end

  def value(marker_count)
    size = size_until_marker(self.marker_count - marker_count)
    slice(pos, size).tap do
      pos = size
    end
  end

  def value
    size = size_until_marker
    slice(pos, size).tap do
      pos = size
    end
  end
end
