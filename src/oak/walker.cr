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
      walker = self
  
      # walk until we reach the marker or end
      while walker.has_next?
        break if walker.marker? && (skip_markers -= 1) < 0
        walker.next_char
      end
  
      # return the size
      return walker.pos - self.pos
    end

    def marker_count
      walker = self
      count = 0
  
      # count the markers until we reach the end
      while reader.has_next?
        count += 1 if walker.marker?
        reader.next_char
      end
  
      count
    end
  
    def end?
      !reader.has_next?
    end
  
    def slice(*args)
      reader.string.byte_slice(*args)
    end
  
    def trailing_slash_end?
      reader.pos + 1 == bytesize && current_char == '/'
    end
  
    def peek_char
      reader.peek_next_char
    end
  
    def marker?
      current_char == '/'
    end
  
    def next_char
      reader.next_char
    end

    def remaining
      slice pos
    end
  end
  