require "./walker"

struct Oak::PathWalker < Oak::Walker
  def value(marker_count)
    size = size_until_marker(self.marker_count - marker_count)
    slice(pos, size).tap do |value|
      self.pos += size
    end
  end

  def value
    size = size_until_marker
    slice(pos, size).tap do
      self.pos += size
    end
  end
end
