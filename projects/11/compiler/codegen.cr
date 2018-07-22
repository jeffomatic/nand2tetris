require "./constants"
require "./ast_node"

module Codegen
  class SymbolTable
    def_clone

    def initialize(klass : ASTNode::Class)
      @decls = {
        Compiler::VarScope::Local    => ({} of String => Int32),
        Compiler::VarScope::Argument => ({} of String => Int32),
        Compiler::VarScope::Field    => ({} of String => Int32),
        Compiler::VarScope::Static   => ({} of String => Int32),
      }

      klass.members.each do |member|
        member.names.each { |n| declare(member.var_scope, n) }
      end
    end

    def declare(var_scope : Compiler::VarScope, identifier : String)
      table = @decls[var_scope]
      table[identifier] = table.size
    end

    def resolve(identifier : String) : Tuple(Compiler::VarScope, Int32)
      @decls.each do |var_scope, offsets|
        return {var_scope, offsets[identifier]} if offsets.has_key?(identifier)
      end

      raise "undeclared variable: #{identifier}"
    end
  end

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
      commands += codegen_subroutine(klass, st.clone, s)
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
      case s
      when ASTNode::Assignment
        commands += codegen_assignment(klass, st, s)
      when ASTNode::Do
        commands += codegen_do(klass, st, s)
      when ASTNode::Return
        commands += codegen_return(klass, st, s)
      else
        raise NotImplementedError.new("statement codegen for #{s.class.name}")
      end
    end

    commands
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

  def self.codegen_do(
    klass : ASTNode::Class,
    st : SymbolTable,
    statement : ASTNode::Do
  ) : Array(String)
    commands = [] of String

    statement.method_call.args.each do |e|
      commands += codegen_expression(klass, st, e)
    end

    parts = [] of String
    klass = statement.method_call.klass
    if !klass.nil?
      parts << klass
    end
    parts << statement.method_call.method
    func = parts.join(".")

    commands << "call #{func} #{statement.method_call.args.size}"
    commands
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
    when ASTNode::Reference
      commands += codegen_reference(klass, st, expr)
    when ASTNode::BinaryOperation
      commands += codegen_binary_operation(klass, st, expr)
    when ASTNode::UnaryOperation
      commands += codegen_unary_operation(klass, st, expr)
    else
      raise NotImplementedError.new("expression not implemented: #{expr.class.name}")
    end

    commands
  end

  def self.codegen_integer_constant(expr : ASTNode::IntegerConstant) : Array(String)
    return ["push constant #{expr.value}"]
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
end
