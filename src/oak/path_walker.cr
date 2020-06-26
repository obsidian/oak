require "./walker"
# :nodoc:
struct Oak::PathWalker < Oak::Walker
  def value(marker_count)
    size = size_until_marker(self.marker_count - marker_count)
    value = slice(pos, size)
    self.pos += size
    value
  end

  def value
    size = size_until_marker
    value = slice(pos, size)
    self.pos += size
    value
  end
end
