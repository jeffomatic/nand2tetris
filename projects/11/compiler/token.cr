require "json"

class Token
  enum Type
    Keyword
    Symbol
    Identifier
    IntegerConstant
    StringConstant
  end

  getter type, value

  def initialize(@type : Type, @value : String)
  end

  def to_json
    {type: type.to_s, value: value}.to_json
  end

  def to_s(io)
    io << to_json
  end
end
