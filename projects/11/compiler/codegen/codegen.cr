require "../parser/node"

module Codegen
  class SymbolTable
    getter vars, subroutines

    def initialize
      @vars = {} of String => Parser::Node::VarDecl
      @subroutines = {} of String => Parser::Node::Subroutine
    end

    def to_h
      {
        vars:        vars,
        subroutines: subroutines,
      }
    end

    def to_json(b : JSON::Builder)
      raise NotImplementedError.new("#to_json")
    end
  end

  def self.collect_globals(nodes : Array(Parser::Node::Base)) : Hash(String, SymbolTable)
    globals = {} of String => SymbolTable

    nodes.each do |class_node|
      raise "invalid top-level node: #{class_node}" unless class_node.is_a?(Parser::Node::Class)

      st = SymbolTable.new

      class_node.members.each do |node|
        if node.scope == Parser::Node::VarDecl::Scope::Local
          raise "cannot use 'var' for class member: #{node}"
        end

        node.names.each do |varname|
          if st.vars.has_key?(varname)
            raise "redeclaration of variable #{varname}; declaration already exists: #{st.vars[varname]}"
          end

          st.vars[varname] = node
        end
      end

      class_node.subroutines.each do |node|
        if st.subroutines.has_key?(node.name)
          raise "redeclaration of subroutine #{node.name}; declaration already exists: #{st.subroutines[node.name]}"
        end

        st.subroutines[node.name] = node
      end

      globals[class_node.name] = st
    end

    globals
  end

  def self.codegen(
    globals : Hash(String, SymbolTable),
    nodes : Array(Parser::Node::Base)
  ) : Array(String)
    commands = [] of String

    nodes.each do |n|
      raise "invalid top-level node: #{n}" unless n.is_a?(Parser::Node::Class)
      commands += codegen_class(globals, n)
    end

    commands
  end

  def self.codegen_class(globals : Hash(String, SymbolTable), klass : Parser::Node::Class) : Array(String)
    commands = [] of String
    klass.subroutines.each { |s| commands += codegen_subroutine(globals, klass, s) }
    commands
  end

  def self.codegen_subroutine(
    globals : Hash(String, SymbolTable),
    klass : Parser::Node::Class,
    subroutine : Parser::Node::Subroutine
  ) : Array(String)
    commands = [
      "function #{klass.name}.#{subroutine.name} #{subroutine.locals.size}"
    ]

    subroutine.body.each do |s|
      case s
      when Parser::Node::Do
        commands += codegen_do(globals, klass, s)
      when Parser::Node::Return
        commands += codegen_return(globals, klass, s)
      else
        raise NotImplementedError.new("statement codegen for #{s.class.name}")
      end
    end

    commands
  end

  def self.codegen_do(
    globals : Hash(String, SymbolTable),
    klass : Parser::Node::Class,
    statement : Parser::Node::Do
  ) : Array(String)
    commands = [] of String

    statement.method_call.args.each do |e|
      commands += codegen_expression(globals, klass, e)
    end

    parts = [] of String
    scope = statement.method_call.scope
    if !scope.nil?
      parts << scope
    end
    parts << statement.method_call.method
    func = parts.join(".")

    commands << "call #{func} #{statement.method_call.args.size}"
    commands
  end

  def self.codegen_return(
    globals : Hash(String, SymbolTable),
    klass : Parser::Node::Class,
    statement : Parser::Node::Return
  ) : Array(String)
    commands = [] of String

    expr = statement.expression
    if !expr.nil?
      commands += codegen_expression(globals, klass, expr)
    else
      commands << "push constant 0"
    end

    commands << "return"
    commands
  end

  def self.codegen_expression(
    globals : Hash(String, SymbolTable),
    klass : Parser::Node::Class,
    expr : Parser::Node::Expression
  ) : Array(String)
    commands = [] of String

    case expr
    when Parser::Node::IntegerConstant
      commands += codegen_integer_constant(expr)
    when Parser::Node::StringConstant
      commands += codegen_string_constant(expr)
    when Parser::Node::BinaryOperation
      commands += codegen_binary_operation(globals, klass, expr)
    when Parser::Node::UnaryOperation
      commands += codegen_unary_operation(globals, klass, expr)
    else
      raise NotImplementedError.new("expression not implemented: #{expr.class.name}")
    end

    commands
  end

  def self.codegen_integer_constant(expr : Parser::Node::IntegerConstant) : Array(String)
    return ["push constant #{expr.value}"]
  end

  def self.codegen_string_constant(expr : Parser::Node::StringConstant) : Array(String)
    commands = [
      "push constant #{expr.value.size}",
      "call String.new 1", # allocate string object; string pointer will be at stack top
    ]

    expr.value.each_char.each_with_index do |c, i|
      commands += [
        "push constant #{c.ord}", # arg 1
        "call String.appendChar 2", # string pointer will be at stack top
      ]
    end

    commands
  end

  def self.codegen_binary_operation(
    globals : Hash(String, SymbolTable),
    klass : Parser::Node::Class,
    expr : Parser::Node::BinaryOperation
  ) : Array(String)
    commands = codegen_expression(globals, klass, expr.left_operand)
    commands += codegen_expression(globals, klass, expr.right_operand)

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
    else raise "invalid binary operator: #{expr.operator}"
    end

    commands
  end

  def self.codegen_unary_operation(
    globals : Hash(String, SymbolTable),
    klass : Parser::Node::Class,
    expr : Parser::Node::UnaryOperation
  ) : Array(String)
    commands = codegen_expression(globals, klass, expr.operand)

    case expr.operator
    when "-" then commands << "neg"
    when "~" then commands << "not"
    else raise "invalid binary operator: #{expr.operator}"
    end

    commands
  end
end
