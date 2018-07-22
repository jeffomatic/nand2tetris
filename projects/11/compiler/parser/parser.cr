require "../constants"
require "../token"
require "../ast_node"

def assert_token!(t : Token?, want_type : Token::Type, want_values : Array(String)? = nil) : Void
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
  def self.parse(tokens : Array(Token)) : Array(ASTNode::Base)
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

  def initialize(@tokens : Array(Token)) : Array(ASTNode::Base)
    @nodes = [] of ASTNode::Base
  end

  def run : Array(ASTNode::Base)
    until @tokens.empty?
      @nodes << parse_class
    end

    @nodes
  end

  def parse_class : ASTNode::Class
    consume_keyword("class")
    name = consume_any_identifier
    consume_symbol("{")

    members = [] of ASTNode::VarDecl
    subroutines = [] of ASTNode::Subroutine
    loop do
      t = peek
      break unless t.type == Token::Type::Keyword

      if CLASS_VAR_KEYWORDS.includes?(t.value)
        members << parse_var_decl
      elsif SUBROUTINE_VARIANT_KEYWORDS.includes?(t.value)
        subroutines << parse_subroutine
      else
        break
      end
    end

    consume_symbol("}")

    ASTNode::Class.new(name: name, members: members, subroutines: subroutines)
  end

  def parse_var_decl : ASTNode::VarDecl
    scope_str = consume_keyword(VAR_KEYWORDS)
    var_scope = Compiler.var_scope_from_decl_string(scope_str)

    type = consume_any_identifier

    names = [] of String
    loop do
      names << consume_any_identifier
      break if test_next(Token::Type::Symbol, ";")
      consume_symbol(",")
    end

    consume_symbol(";")

    ASTNode::VarDecl.new(var_scope: var_scope, type: type, names: names)
  end

  def parse_subroutine : ASTNode::Subroutine
    variant_str = consume_keyword(SUBROUTINE_VARIANT_KEYWORDS)
    variant = ASTNode::Subroutine.variant_from_string(variant_str)
    return_type = consume_any_identifier

    name = consume_any_identifier
    consume_symbol("(")

    parameters = [] of ASTNode::Parameter
    loop do
      break if test_next(Token::Type::Symbol, ")")

      consume_symbol(",") if parameters.size > 0

      parameters << ASTNode::Parameter.new(
        type: consume_any_identifier,
        name: consume_any_identifier
      )
    end

    consume_symbol(")")

    locals, body = parse_statement_block

    ASTNode::Subroutine.new(
      variant: variant,
      return_type: return_type,
      name: name,
      parameters: parameters,
      locals: locals,
      body: body
    )
  end

  def parse_statement_block : Tuple(Array(ASTNode::VarDecl), Array(ASTNode::Statement))
    consume_symbol("{")

    locals = [] of ASTNode::VarDecl
    while test_next(Token::Type::Keyword, "var")
      locals << parse_var_decl
    end

    statements = [] of ASTNode::Statement
    loop do
      break if test_next(Token::Type::Symbol, "}")
      statements << parse_statement
    end

    consume_symbol("}")

    return {locals, statements}
  end

  def parse_statement : ASTNode::Statement
    raise "unexpected statement token #{peek}" unless peek.type == Token::Type::Keyword

    case peek.value
    when "let"
      parse_assignment_statement
    when "if"
      parse_conditional_statement
    when "while"
      parse_loop_statement
    when "do"
      parse_do_statement
    when "return"
      parse_return_statement
    else
      raise "unexpected statement token #{peek}"
    end
  end

  def parse_assignment_statement : ASTNode::Assignment
    consume_keyword("let")
    assignee = consume_any_identifier
    consume_symbol("=")
    expression = parse_expression_until([";"])
    s = ASTNode::Assignment.new(assignee: assignee, expression: expression)
    consume_symbol(";")
    s
  end

  def parse_conditional_statement : ASTNode::Conditional
    consume_keyword("if")
    consume_symbol("(")
    condition = parse_expression_until([")"])
    consume_symbol(")")

    locals, consequence = parse_statement_block
    raise "cannot declare locals in conditional" unless locals.empty?

    alternative = [] of ASTNode::Statement
    if test_next(Token::Type::Keyword, "else")
      consume
      locals, alternative = parse_statement_block
      raise "cannot declare locals in conditional" unless locals.empty?
    end

    ASTNode::Conditional.new(
      condition: condition,
      consequence: consequence,
      alternative: alternative
    )
  end

  def parse_loop_statement : ASTNode::Loop
    consume_keyword("while")
    consume_symbol("(")
    condition = parse_expression_until([")"])
    consume_symbol(")")

    locals, body = parse_statement_block
    raise "cannot declare locals in conditional" unless locals.empty?

    ASTNode::Loop.new(
      condition: condition,
      body: body
    )
  end

  def parse_do_statement : ASTNode::Do
    consume
    expr = parse_expression_until([";"])
    consume_symbol(";")
    raise "want MethodCall statement, got: #{expr}" unless expr.is_a? ASTNode::MethodCall
    ASTNode::Do.new(method_call: expr)
  end

  def parse_return_statement : ASTNode::Return
    consume
    expr = nil
    if !test_next(Token::Type::Symbol, ";")
      expr = parse_expression_until([";"])
    end
    consume_symbol(";")
    ASTNode::Return.new(expression: expr)
  end

  def parse_expression_until(terminators : Array(String)) : ASTNode::Expression
    expr = nil
    t = consume

    case t.type
    when Token::Type::Symbol
      if UNARY_OP_SYMBOLS.includes?(t.value)
        expr = ASTNode::UnaryOperation.new(
          operator: t.value,
          operand: parse_expression_until(terminators)
        )
      elsif t.value == "("
        expr = parse_expression_until([")"])
        consume_symbol(")")
      elsif terminators.includes?(t.value)
        raise "empty expression ending with #{t}"
      end
    when Token::Type::IntegerConstant
      expr = ASTNode::IntegerConstant.new(value: t.value)
    when Token::Type::StringConstant
      expr = ASTNode::StringConstant.new(value: t.value)
    when Token::Type::Identifier
      expr = ASTNode::Reference.new(identifier: t.value)
    end

    raise "invalid token: #{t}" if expr.nil?

    # Now perform lookahead for terminators, binary operators, and method calls

    raise "invalid token: #{peek}" unless peek.type == Token::Type::Symbol

    # Check for terminator

    return expr if terminators.includes?(peek.value)

    # Check for binary operator

    if BINARY_OP_SYMBOLS.includes?(peek.value)
      operator = consume.value
      return ASTNode::BinaryOperation.new(
        operator: operator,
        left_operand: expr,
        right_operand: parse_expression_until(terminators)
      )
    end

    # Check for method call

    raise "invalid token #{peek}" unless expr.is_a?(ASTNode::Reference)

    if peek.value == "."
      consume
      klass = expr.identifier
      method = consume_any_identifier
    else
      klass = nil
      method = expr.identifier
    end

    consume_symbol("(")

    args = [] of ASTNode::Expression
    if !test_next(Token::Type::Symbol, ")")
      loop do
        args << parse_expression_until([",", ")"])
        break if test_next(Token::Type::Symbol, ")")
        consume_symbol(",")
      end
    end

    consume_symbol(")")

    return ASTNode::MethodCall.new(
      klass: klass,
      method: method,
      args: args
    )
  end

  def consume : Token
    @tokens.shift
  end

  def peek : Token
    @tokens.first
  end

  def consume_keyword(value : String) : Void
    t = consume
    assert_token!(t, Token::Type::Keyword, [value])
  end

  def consume_keyword(values : Array(String)) : String
    t = consume
    assert_token!(t, Token::Type::Keyword, values)
    t.value
  end

  def consume_any_identifier : String
    t = consume
    assert_token!(t, Token::Type::Identifier)
    t.value
  end

  def consume_symbol(value : String) : String
    t = consume
    assert_token!(t, Token::Type::Symbol, [value])
    t.value
  end

  def test_next(type : Token::Type, value : String) : Bool
    t = peek

    return false if t.nil?
    return false if t.type != type

    value == t.value
  end
end
