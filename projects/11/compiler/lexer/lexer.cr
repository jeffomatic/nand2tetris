require "./constants"
require "../token"

class Lexer
  def self.lex(io : IO) : Array(Token)
    lexer = self.new(io)
    lexer.run
    lexer.tokens
  end

  getter tokens

  def initialize(@io : IO)
    @tokens = [] of Token

    @state = State::None
    @escape = false
    @value = ""

    @line = 0
    @column = 0
    @redo_current = false
    @skip_next = false
  end

  def run
    @line = 1
    @column = 1

    while true
      next_line = @line
      next_column = @column

      if @redo_current
        @redo_current = false
      else
        c = @io.read_char

        case c
        when '\n'
          next_line = @line + 1
          next_column = 1
        when '\r'
          # do nothing
        else
          next_column = @column + 1
        end
      end

      if @skip_next
        @skip_next = false
      else
        case @state
        when State::None                then none_handler(c)
        when State::KeywordOrIdentifier then keyword_or_identifier_handler(c)
        when State::IntegerConstant     then integer_constant_handler(c)
        when State::StringConstant      then string_constant_handler(c)
        when State::CommentLine         then comment_line_handler(c)
        when State::CommentMulti        then comment_multi_handler(c)
        end
      end

      break if c.nil? && !@redo_current

      @line = next_line
      @column = next_column
    end
  end

  def peek : Slice(Char)
    @io.peek.not_nil!.map { |b| b.chr }
  end

  def redo_current : Void
    @redo_current = true
  end

  def skip_next : Void
    @skip_next = true
  end

  def symbol?(c : Char?)
    SYMBOLS.includes?(c)
  end

  def newline?(c : Char?)
    c == '\n' || c == '\r'
  end

  def none_handler(c : Char?)
    if c.nil? || c.whitespace?
      return
    end

    if c.letter? || c == '_'
      change_state(State::KeywordOrIdentifier)
      @value += c
      return
    end

    # '/' is a special case of symbol?(c)
    if c == '/'
      case peek[0]
      when '/'
        change_state(State::CommentLine)
        skip_next
      when '*'
        change_state(State::CommentMulti)
        skip_next
      else
        @tokens << Token.new(Token::Type::Symbol, "/")
      end

      return
    end

    if symbol?(c)
      # Symbols are only a single character
      @tokens << Token.new(Token::Type::Symbol, c.to_s)
      return
    end

    if c.number?
      change_state(State::IntegerConstant)
      @value += c
      return
    end

    if c == '"'
      change_state(State::StringConstant)
      return
    end

    invalid_char(c)
  end

  def keyword_or_identifier_handler(c : Char?)
    if c.nil? || c.whitespace?
      finish_keyword_or_identifier
      change_state(State::None)
      return
    end

    if symbol?(c)
      finish_keyword_or_identifier
      change_state(State::None)
      redo_current
      return
    end

    if c.number? || c.letter? || c == '_'
      @value += c
      return
    end

    invalid_char(c)
  end

  def finish_keyword_or_identifier
    if KEYWORDS.includes?(@value)
      @tokens << Token.new(Token::Type::Keyword, @value)
    else
      @tokens << Token.new(Token::Type::Identifier, @value)
    end
  end

  def integer_constant_handler(c : Char?)
    if c.nil? || c.whitespace?
      finish_integer_constant
      change_state(State::None)
      return
    end

    if symbol?(c)
      finish_integer_constant
      change_state(State::None)
      redo_current
      return
    end

    # Cannot have zero-prefixed integer constants
    if @value[0] == '0'
      invalid_char(c)
    end

    if c.number?
      @value += c
      return
    end

    invalid_char(c)
  end

  def finish_integer_constant
    @tokens << Token.new(Token::Type::IntegerConstant, @value)
  end

  def string_constant_handler(c : Char?)
    if c.nil? || newline?(c)
      error("invalid newline in string constant")
    end

    if @escape
      @value += c
      @escape = false
      return
    end

    if c == '\\'
      @escape = true
      return
    end

    if c == '"'
      @tokens << Token.new(Token::Type::StringConstant, @value)
      change_state(State::None)
      return
    end

    @value += c
  end

  def comment_line_handler(c : Char?)
    if newline?(c)
      change_state(State::None)
      return
    end
  end

  def comment_multi_handler(c : Char?)
    if c == '*' && peek[0] == '/'
      skip_next # consume slash char
      change_state(State::None)
      return
    end
  end

  def change_state(s : State)
    @state = s
    @value = ""
    @escape = false
  end

  def invalid_char(c : Char?)
    error("invalid char: #{c}")
  end

  def error(s : String)
    raise "Line #{@line}, column #{@column} #{@state}: #{s}"
  end
end
