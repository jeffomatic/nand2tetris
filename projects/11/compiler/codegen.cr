require "./constants"
require "./ast_node"
require "./symbol_table"

module Codegen
  def self.codegen(nodes : Array(ASTNode::Base)) : Array(String)
    commands = [] of String

    nodes.each do |n|
      raise "invalid top-level node: #{n}" unless n.is_a?(ASTNode::Class)
      commands += codegen_class(n)
    end

    commands
  end

  def self.codegen_class(klass : ASTNode::Class) : Array(String)
    commands = [] of String
    st = SymbolTable.new(klass)

    klass.subroutines.each do |s|
      subroutine_symbols = st.clone
      if s.variant == ASTNode::Subroutine::Variant::ClassMethod
        subroutine_symbols.clear(Compiler::VarScope::Field)
      end

      commands += codegen_subroutine(klass, subroutine_symbols, s)
    end

    commands
  end

  def self.codegen_subroutine(
    klass : ASTNode::Class,
    st : SymbolTable,
    subroutine : ASTNode::Subroutine
  ) : Array(String)
    subroutine.parameters.each do |param|
      st.declare(Compiler::VarScope::Argument, param.name)
    end

    subroutine.locals.each do |var_decl|
      var_decl.names.each do |n|
        st.declare(Compiler::VarScope::Local, n)
      end
    end

    num_locals = subroutine.locals.reduce(0) do |memo, decl|
      memo += decl.names.size
    end

    commands = [
      "function #{klass.name}.#{subroutine.name} #{num_locals}",
    ]

    subroutine.body.each do |s|
      commands += codegen_statement(klass, st, s)
    end

    commands
  end

  def self.codegen_statement(
    klass : ASTNode::Class,
    st : SymbolTable,
    statement : ASTNode::Statement
  ) : Array(String)
    case statement
    when ASTNode::Assignment
      codegen_assignment(klass, st, statement)
    when ASTNode::Conditional
      codegen_conditional(klass, st, statement)
    when ASTNode::Loop
      codegen_loop(klass, st, statement)
    when ASTNode::Do
      codegen_do(klass, st, statement)
    when ASTNode::Return
      codegen_return(klass, st, statement)
    else
      raise NotImplementedError.new("statement codegen for #{statement.class.name}")
    end
  end

  def self.codegen_assignment(
    klass : ASTNode::Class,
    st : SymbolTable,
    statement : ASTNode::Assignment
  ) : Array(String)
    commands = codegen_expression(klass, st, statement.expression)

    var_scope, offset = st.resolve(statement.assignee)
    commands << "pop #{Compiler.var_scope_to_segment(var_scope)} #{offset}"

    commands
  end

  @@next_conditional_index = 0

  def self.codegen_conditional(
    klass : ASTNode::Class,
    st : SymbolTable,
    statement : ASTNode::Conditional
  ) : Array(String)
    conditional_prefix = "label#{@@next_conditional_index}"
    @@next_conditional_index += 1

    commands = codegen_expression(klass, st, statement.condition)
    commands << "if-goto #{conditional_prefix}_if_true"

    statement.alternative.each do |s|
      commands += codegen_statement(klass, st, s)
    end

    commands += [
      "goto #{conditional_prefix}_if_end",
      "label #{conditional_prefix}_if_true",
    ]

    statement.consequence.each do |s|
      commands += codegen_statement(klass, st, s)
    end

    commands << "label #{conditional_prefix}_if_end"
    commands
  end

  @@next_loop_index = 0

  def self.codegen_loop(
    klass : ASTNode::Class,
    st : SymbolTable,
    statement : ASTNode::Loop
  ) : Array(String)
    label_prefix = "label#{@@next_loop_index}"
    @@next_loop_index += 1

    commands = ["label #{label_prefix}_start"]
    commands += codegen_expression(klass, st, statement.condition)
    commands += [
      "not",
      "if-goto #{label_prefix}_end",
    ]

    statement.body.each do |s|
      commands += codegen_statement(klass, st, s)
    end

    commands += [
      "goto #{label_prefix}_start",
      "label #{label_prefix}_end",
    ]

    commands
  end

  def self.codegen_do(
    klass : ASTNode::Class,
    st : SymbolTable,
    statement : ASTNode::Do
  ) : Array(String)
    commands = codegen_method_call(klass, st, statement.method_call)
  end

  def self.codegen_return(
    klass : ASTNode::Class,
    st : SymbolTable,
    statement : ASTNode::Return
  ) : Array(String)
    commands = [] of String

    expr = statement.expression
    if !expr.nil?
      commands += codegen_expression(klass, st, expr)
    else
      commands << "push constant 0"
    end

    commands << "return"
    commands
  end

  def self.codegen_expression(
    klass : ASTNode::Class,
    st : SymbolTable,
    expr : ASTNode::Expression
  ) : Array(String)
    commands = [] of String

    case expr
    when ASTNode::IntegerConstant
      commands += codegen_integer_constant(expr)
    when ASTNode::StringConstant
      commands += codegen_string_constant(expr)
    when ASTNode::BooleanConstant
      commands += codegen_boolean_constant(expr)
    when ASTNode::NullConstant
      commands += codegen_null_constant
    when ASTNode::Reference
      commands += codegen_reference(klass, st, expr)
    when ASTNode::BinaryOperation
      commands += codegen_binary_operation(klass, st, expr)
    when ASTNode::UnaryOperation
      commands += codegen_unary_operation(klass, st, expr)
    when ASTNode::MethodCall
      commands += codegen_method_call(klass, st, expr)
    else
      raise NotImplementedError.new("expression not implemented: #{expr.class.name}")
    end

    commands
  end

  def self.codegen_integer_constant(expr : ASTNode::IntegerConstant) : Array(String)
    return ["push constant #{expr.value}"]
  end

  def self.codegen_boolean_constant(expr : ASTNode::BooleanConstant) : Array(String)
    expr.value ? ["push constant 0", "not"] : ["push constant 0"]
  end

  def self.codegen_null_constant : Array(String)
    ["push constant 0"]
  end

  def self.codegen_string_constant(expr : ASTNode::StringConstant) : Array(String)
    commands = [
      "push constant #{expr.value.size}",
      "call String.new 1", # allocate string object; string pointer will be at stack top
    ]

    expr.value.each_char.each_with_index do |c, i|
      commands += [
        "push constant #{c.ord}",   # arg 1
        "call String.appendChar 2", # string pointer will be at stack top
      ]
    end

    commands
  end

  def self.codegen_reference(
    klass : ASTNode::Class,
    st : SymbolTable,
    expr : ASTNode::Reference
  ) : Array(String)
    var_scope, offset = st.resolve(expr.identifier)
    ["push #{Compiler.var_scope_to_segment(var_scope)} #{offset}"]
  end

  def self.codegen_binary_operation(
    klass : ASTNode::Class,
    st : SymbolTable,
    expr : ASTNode::BinaryOperation
  ) : Array(String)
    commands = codegen_expression(klass, st, expr.left_operand)
    commands += codegen_expression(klass, st, expr.right_operand)

    case expr.operator
    when "+" then commands << "add"
    when "-" then commands << "sub"
    when "*" then commands << "call Math.multiply 2"
    when "/" then commands << "call Math.divide 2"
    when "&" then commands << "and"
    when "|" then commands << "or"
    when "<" then commands << "lt"
    when ">" then commands << "gt"
    when "=" then commands << "eq"
    else          raise "invalid binary operator: #{expr.operator}"
    end

    commands
  end

  def self.codegen_unary_operation(
    klass : ASTNode::Class,
    st : SymbolTable,
    expr : ASTNode::UnaryOperation
  ) : Array(String)
    commands = codegen_expression(klass, st, expr.operand)

    case expr.operator
    when "-" then commands << "neg"
    when "~" then commands << "not"
    else          raise "invalid binary operator: #{expr.operator}"
    end

    commands
  end

  def self.codegen_method_call(
    klass : ASTNode::Class,
    st : SymbolTable,
    method_call : ASTNode::MethodCall
  ) : Array(String)
    commands = [] of String

    method_call.args.each do |e|
      commands += codegen_expression(klass, st, e)
    end

    if !method_call.klass.nil?
      commands << "call #{method_call.klass}.#{method_call.method} #{method_call.args.size}"
    else
      commands << "call #{klass.name}.#{method_call.method} #{method_call.args.size}"
    end

    commands
  end
end
