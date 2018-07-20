require "../lexer/token"
require "./node"

def assert_token!(t : Lexer::Token?, want_type : Lexer::Token::Type, want_values : Array(String)? = nil) : Void
  if t.nil?
    raise "nil token, want type #{want_type}, want value in #{want_values.inspect}"
  end

  if t.type != want_type
    raise "Invalid token #{t}: type is #{t.type}, want #{want_type}"
  end

  if !want_values.nil? && !want_values.includes?(t.value)
    raise "Invalid token #{t}: value is #{t.value}, want any of #{want_values.inspect}"
  end
end

class Parser
  def self.parse(tokens : Array(Lexer::Token)) : Array(Node::Base)
    new(tokens).run
  end

  getter nodes

  CLASS_VAR_KEYWORDS          = ["field", "static"]
  LOCAL_VAR_KEYWORDS          = ["var"]
  VAR_KEYWORDS                = CLASS_VAR_KEYWORDS + LOCAL_VAR_KEYWORDS
  SUBROUTINE_VARIANT_KEYWORDS = ["constructor", "method", "function"]
  STATEMENT_VARIANT_KEYWORDS  = ["let", "if", "while", "do", "return"]
  BINARY_OP_SYMBOLS           = ["+", "-", "*", "/", "&", "|", "<", ">", "="]
  UNARY_OP_SYMBOLS            = ["~", "-"]

  def initialize(@tokens : Array(Lexer::Token)) : Array(Node::Base)
    @nodes = [] of Node::Base
  end

  def run : Array(Node::Base)
    until @tokens.empty?
      @nodes << parse_class
    end

    @nodes
  end

  def parse_class : Node::Class
    consume_keyword("class")
    name = consume_any_identifier
    consume_symbol("{")

    members = [] of Node::VarDecl
    subroutines = [] of Node::Subroutine
    loop do
      t = peek
      break unless t.type == Lexer::Token::Type::Keyword

      if CLASS_VAR_KEYWORDS.includes?(t.value)
        members << parse_var_decl
      elsif SUBROUTINE_VARIANT_KEYWORDS.includes?(t.value)
        subroutines << parse_subroutine
      else
        break
      end
    end

    consume_symbol("}")

    Node::Class.new(name: name, members: members, subroutines: subroutines)
  end

  def parse_var_decl : Node::VarDecl
    scope_str = consume_keyword(VAR_KEYWORDS)
    scope = Node::VarDecl.scope_from_string(scope_str)
    type = consume_any_identifier

    names = [] of String
    loop do
      names << consume_any_identifier
      break if test_next(Lexer::Token::Type::Symbol, ";")
      consume_symbol(",")
    end

    consume_symbol(";")

    Node::VarDecl.new(scope: scope, type: type, names: names)
  end

  def parse_subroutine : Node::Subroutine
    variant_str = consume_keyword(SUBROUTINE_VARIANT_KEYWORDS)
    variant = Node::Subroutine.variant_from_string(variant_str)
    return_type = consume_any_identifier

    name = consume_any_identifier
    consume_symbol("(")

    parameters = [] of Node::Parameter
    loop do
      break if test_next(Lexer::Token::Type::Symbol, ")")

      consume_symbol(",") if parameters.size > 0

      parameters << Node::Parameter.new(
        type: consume_any_identifier,
        name: consume_any_identifier
      )
    end

    consume_symbol(")")

    locals, body = parse_statement_block

    Node::Subroutine.new(
      variant: variant,
      return_type: return_type,
      name: name,
      parameters: parameters,
      locals: locals,
      body: body
    )
  end

  def parse_statement_block : Tuple(Array(Node::VarDecl), Array(Node::Statement))
    consume_symbol("{")

    locals = [] of Node::VarDecl
    while test_next(Lexer::Token::Type::Keyword, "var")
      locals << parse_var_decl
    end

    statements = [] of Node::Statement
    loop do
      break if test_next(Lexer::Token::Type::Symbol, "}")
      statements << parse_statement
    end

    consume_symbol("}")

    return {locals, statements}
  end

  def parse_statement : Node::Statement
    raise "unexpected statement token #{peek}" unless peek.type == Lexer::Token::Type::Keyword

    case peek.value
    when "let"
      parse_assignment_statement
    when "if"
      parse_conditional_statement
    when "while"
      parse_loop_statement
    when "do"
      parse_do_statement
    else
      raise "unexpected statement token #{peek}"
    end
  end

  def parse_assignment_statement : Node::Assignment
    consume_keyword("let")
    assignee = consume_any_identifier
    consume_symbol("=")
    expression = parse_expression_until([";"])
    s = Node::Assignment.new(assignee: assignee, expression: expression)
    consume_symbol(";")
    s
  end

  def parse_conditional_statement : Node::Conditional
    consume_keyword("if")
    consume_symbol("(")
    condition = parse_expression_until([")"])
    consume_symbol(")")

    locals, consequence = parse_statement_block
    raise "cannot declare locals in conditional" unless locals.empty?

    alternative = [] of Node::Statement
    if test_next(Lexer::Token::Type::Keyword, "else")
      consume
      locals, alternative = parse_statement_block
      raise "cannot declare locals in conditional" unless locals.empty?
    end

    Node::Conditional.new(
      condition: condition,
      consequence: consequence,
      alternative: alternative
    )
  end

  def parse_loop_statement : Node::Loop
    consume_keyword("while")
    consume_symbol("(")
    condition = parse_expression_until([")"])
    consume_symbol(")")

    locals, body = parse_statement_block
    raise "cannot declare locals in conditional" unless locals.empty?

    Node::Loop.new(
      condition: condition,
      body: body
    )
  end

  def parse_do_statement : Node::Do
    consume
    expr = parse_expression_until([";"])
    consume_symbol(";")
    raise "want MethodCall statement, got: #{expr}" unless expr.is_a? Node::MethodCall
    Node::Do.new(method_call: expr)
  end

  def parse_expression_until(terminators : Array(String)) : Node::Expression
    expr = nil
    t = consume

    case t.type
    when Lexer::Token::Type::Symbol
      if UNARY_OP_SYMBOLS.includes?(t.value)
        expr = Node::UnaryOperation.new(
          operator: t.value,
          operand: parse_expression_until(terminators)
        )
      elsif t.value == "("
        expr = parse_expression_until([")"])
        consume_symbol(")")
      elsif terminators.includes?(t.value)
        raise "empty expression ending with #{t}"
      end
    when Lexer::Token::Type::IntegerConstant
      expr = Node::IntegerConstant.new(value: t.value)
    when Lexer::Token::Type::StringConstant
      expr = Node::StringConstant.new(value: t.value)
    when Lexer::Token::Type::Identifier
      expr = Node::Reference.new(identifier: t.value)
    end

    raise "invalid token: #{t}" if expr.nil?

    # Now perform lookahead for terminators, binary operators, and method calls

    raise "invalid token: #{peek}" unless peek.type == Lexer::Token::Type::Symbol

    # Check for terminator

    return expr if terminators.includes?(peek.value)

    # Check for binary operator

    if BINARY_OP_SYMBOLS.includes?(peek.value)
      operator = consume.value
      return Node::BinaryOperation.new(
        operator: operator,
        left_operand: expr,
        right_operand: parse_expression_until(terminators)
      )
    end

    # Check for method call

    raise "invalid token #{peek}" unless expr.is_a?(Node::Reference)

    if peek.value == "."
      consume
      scope = expr.identifier
      method = consume_any_identifier
    else
      scope = nil
      method = expr.identifier
    end

    consume_symbol("(")

    args = [] of Node::Expression
    if !test_next(Lexer::Token::Type::Symbol, ")")
      loop do
        args << parse_expression_until([",", ")"])
        break if test_next(Lexer::Token::Type::Symbol, ")")
        consume_symbol(",")
      end
    end

    consume_symbol(")")

    return Node::MethodCall.new(
      scope: scope,
      method: method,
      args: args
    )
  end

  def consume : Lexer::Token
    @tokens.shift
  end

  def peek : Lexer::Token
    @tokens.first
  end

  def consume_keyword(value : String) : Void
    t = consume
    assert_token!(t, Lexer::Token::Type::Keyword, [value])
  end

  def consume_keyword(values : Array(String)) : String
    t = consume
    assert_token!(t, Lexer::Token::Type::Keyword, values)
    t.value
  end

  def consume_any_identifier : String
    t = consume
    assert_token!(t, Lexer::Token::Type::Identifier)
    t.value
  end

  def consume_symbol(value : String) : String
    t = consume
    assert_token!(t, Lexer::Token::Type::Symbol, [value])
    t.value
  end

  def test_next(type : Lexer::Token::Type, value : String) : Bool
    t = peek

    return false if t.nil?
    return false if t.type != type

    value == t.value
  end
end
