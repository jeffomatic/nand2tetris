require "json"

class CodeLoc
  def initialize(
    @line : Int32,
    @col : Int32
  )
  end

  def to_s(io : IO)
    io << "#{@line}:#{@col}"
  end
end

class Token
  enum Type
    Keyword
    Symbol
    Identifier
    IntegerConstant
    StringConstant
  end

  getter type, value

  def initialize(@type : Type, @value : String, @code_loc : CodeLoc)
  end

  def to_json
    {type: type.to_s, value: value, loc: @code_loc.to_s}.to_json
  end

  def to_s(io)
    io << to_json
  end
end
