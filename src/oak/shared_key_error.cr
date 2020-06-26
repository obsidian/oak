# The error class that is returned in the case of a shared key conflict.
class Oak::SharedKeyError < Exception
  def initialize(new_key, existing_key)
    super("Tried to place key '#{new_key}' at same level as '#{existing_key}'")
  end
end
