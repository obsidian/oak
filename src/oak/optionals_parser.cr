struct Oak::OptionalsParser
  class Context
    property path = ""
    property? placeholder = false
    getter children = [] of OptionalsParser
  end
  @context = Context.new
  delegate placeholder?, path, children, to: @context

  def self.parse(path)
    new(path).results
  end

  def initialize(string : String)
		next_child = ""
    reader = Char::Reader.new(string)
    depth = 0
  	while reader.has_next?
      # puts reader.current_char
      case char = reader.current_char
      when '('
        next_child += char if depth > 0
        depth += 1
      when ')'
        next_child += char if depth > 1
        if depth == 1 && next_child.size > 0
          self << OptionalsParser.new(next_child)
          next_child = ""
          @context.placeholder = reader.has_next?
        end
	      depth -= 1
	    else
        if depth > 0 || placeholder?
	      	next_child += char
        else
          append char
        end
      end
      reader.next_char
	  end
    self << OptionalsParser.new(next_child) if placeholder?
	end

  def <<(child)
    children.each do |c|
      c << child
    end
    children << child
  end

  def append(char)
    @context.path += char
    children.each do |c|
      c.append char
    end
  end

  def results(prefix = "") : Array(String)
		([] of String).tap do |ary|
		  ary << prefix + path unless placeholder?
  		children.each do |child|
		    ary.concat child.results(prefix + path)
		  end
    end
  end
end
