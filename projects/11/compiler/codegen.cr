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
    num_locals = 0

    # Constructors and instance methods must define a "this" parameter, either
    # created as a local or provided by the caller.
    case subroutine.variant
    when ASTNode::Subroutine::Variant::Constructor
      st.declare(
        var_scope: Compiler::VarScope::Local,
        type: klass.name,
        identifier: "this"
      )
      num_locals += 1
    when ASTNode::Subroutine::Variant::InstanceMethod
      st.declare(
        var_scope: Compiler::VarScope::Argument,
        type: klass.name,
        identifier: "this"
      )
    else
      # only instance methods and constructors need "this"
    end

    subroutine.parameters.each do |param|
      st.declare(
        var_scope: Compiler::VarScope::Argument,
        type: param.type,
        identifier: param.name
      )
    end

    subroutine.locals.each do |var_decl|
      var_decl.names.each do |n|
        st.declare(
          var_scope: Compiler::VarScope::Local,
          type: var_decl.type,
          identifier: n
        )
      end
    end

    num_locals += subroutine.locals.reduce(0) do |memo, decl|
      memo += decl.names.size
    end

    commands = ["function #{klass.name}.#{subroutine.name} #{num_locals}"]

    # Constructors need to allocate memory for the instance, and then set the
    # proper value of the "this" variable
    if subroutine.variant == ASTNode::Subroutine::Variant::Constructor
      commands += [
        "push constant #{klass.count_instance_vars}",
        "call Memory.alloc 1",
        st.resolve("this").pop_command,
      ]
    end

    # Constructors and instance methods should set up the THIS segment
    if subroutine.variant == ASTNode::Subroutine::Variant::Constructor ||
       subroutine.variant == ASTNode::Subroutine::Variant::InstanceMethod
      commands += [
        st.resolve("this").push_command,
        "pop pointer 0",
      ]
    end

    subroutine.body.each do |statement|
      commands += codegen_statement(klass, st, subroutine.variant, statement)
    end

    commands
  end

  def self.codegen_statement(
    klass : ASTNode::Class,
    st : SymbolTable,
    sv : ASTNode::Subroutine::Variant,
    statement : ASTNode::Statement
  ) : Array(String)
    case statement
    when ASTNode::Assignment
      codegen_assignment(klass, st, sv, statement)
    when ASTNode::Conditional
      codegen_conditional(klass, st, sv, statement)
    when ASTNode::Loop
      codegen_loop(klass, st, sv, statement)
    when ASTNode::Do
      codegen_do(klass, st, sv, statement)
    when ASTNode::Return
      codegen_return(klass, st, sv, statement)
    else
      raise NotImplementedError.new("statement codegen for #{statement.class.name}")
    end
  end

  def self.codegen_assignment(
    klass : ASTNode::Class,
    st : SymbolTable,
    sv : ASTNode::Subroutine::Variant,
    statement : ASTNode::Assignment
  ) : Array(String)
    # Push evaluated RHS value onto stack
    commands = codegen_expression(klass, st, sv, statement.value_expression)

    # Assignee can be a plain variable or an array expression
    oe = statement.offset_expression
    if !oe.nil?
      # Push the base address
      commands << st.resolve(statement.assignee).push_command

      # Push the offset
      commands += codegen_expression(klass, st, sv, oe)

      # Add the offset to the base address and initialize the THAT segment
      commands += [
        "add",           # add offset to base address
        "pop pointer 1", # initialize THAT segment
        "pop that 0",    # write RHS value to target
      ]
    else
      # Pop the RHS value to the target variable
      commands << st.resolve(statement.assignee).pop_command
    end

    commands
  end

  @@next_conditional_index = 0

  def self.codegen_conditional(
    klass : ASTNode::Class,
    st : SymbolTable,
    sv : ASTNode::Subroutine::Variant,
    statement : ASTNode::Conditional
  ) : Array(String)
    conditional_prefix = "label#{@@next_conditional_index}"
    @@next_conditional_index += 1

    commands = codegen_expression(klass, st, sv, statement.condition)
    commands << "if-goto #{conditional_prefix}_if_true"

    statement.alternative.each do |s|
      commands += codegen_statement(klass, st, sv, s)
    end

    commands += [
      "goto #{conditional_prefix}_if_end",
      "label #{conditional_prefix}_if_true",
    ]

    statement.consequence.each do |s|
      commands += codegen_statement(klass, st, sv, s)
    end

    commands << "label #{conditional_prefix}_if_end"
    commands
  end

  @@next_loop_index = 0

  def self.codegen_loop(
    klass : ASTNode::Class,
    st : SymbolTable,
    sv : ASTNode::Subroutine::Variant,
    statement : ASTNode::Loop
  ) : Array(String)
    label_prefix = "label#{@@next_loop_index}"
    @@next_loop_index += 1

    commands = ["label #{label_prefix}_start"]
    commands += codegen_expression(klass, st, sv, statement.condition)
    commands += [
      "not",
      "if-goto #{label_prefix}_end",
    ]

    statement.body.each do |s|
      commands += codegen_statement(klass, st, sv, s)
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
    sv : ASTNode::Subroutine::Variant,
    statement : ASTNode::Do
  ) : Array(String)
    commands = codegen_method_call(klass, st, sv, statement.method_call)
  end

  def self.codegen_return(
    klass : ASTNode::Class,
    st : SymbolTable,
    sv : ASTNode::Subroutine::Variant,
    statement : ASTNode::Return
  ) : Array(String)
    commands = [] of String

    expr = statement.expression
    if !expr.nil?
      commands += codegen_expression(klass, st, sv, expr)
    else
      commands << "push constant 0"
    end

    commands << "return"
    commands
  end

  def self.codegen_expression(
    klass : ASTNode::Class,
    st : SymbolTable,
    sv : ASTNode::Subroutine::Variant,
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
      commands += codegen_reference(klass, st, sv, expr)
    when ASTNode::BinaryOperation
      commands += codegen_binary_operation(klass, st, sv, expr)
    when ASTNode::UnaryOperation
      commands += codegen_unary_operation(klass, st, sv, expr)
    when ASTNode::ArrayAccess
      commands += codegen_array_access(klass, st, sv, expr)
    when ASTNode::MethodCall
      commands += codegen_method_call(klass, st, sv, expr)
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
    sv : ASTNode::Subroutine::Variant,
    expr : ASTNode::Reference
  ) : Array(String)
    [st.resolve(expr.identifier).push_command]
  end

  def self.codegen_binary_operation(
    klass : ASTNode::Class,
    st : SymbolTable,
    sv : ASTNode::Subroutine::Variant,
    expr : ASTNode::BinaryOperation
  ) : Array(String)
    commands = codegen_expression(klass, st, sv, expr.left_operand)
    commands += codegen_expression(klass, st, sv, expr.right_operand)

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
    sv : ASTNode::Subroutine::Variant,
    expr : ASTNode::UnaryOperation
  ) : Array(String)
    commands = codegen_expression(klass, st, sv, expr.operand)

    case expr.operator
    when "-" then commands << "neg"
    when "~" then commands << "not"
    else          raise "invalid binary operator: #{expr.operator}"
    end

    commands
  end

  def self.codegen_array_access(
    klass : ASTNode::Class,
    st : SymbolTable,
    sv : ASTNode::Subroutine::Variant,
    array_access : ASTNode::ArrayAccess
  ) : Array(String)
    # Push base address
    commands = [st.resolve(array_access.varname).push_command]

    # Push offset onto stack
    commands += codegen_expression(
      klass,
      st,
      sv,
      array_access.offset_expression
    )

    commands += [
      "add",           # add offset to base address
      "pop pointer 1", # initialize THAT segment
      "push that 0",   # push value onto stack
    ]
  end

  def self.codegen_method_call(
    klass : ASTNode::Class,
    st : SymbolTable,
    sv : ASTNode::Subroutine::Variant,
    method_call : ASTNode::MethodCall
  ) : Array(String)
    commands = [] of String
    arg_count = 0
    scope_identifier = method_call.scope_identifier

    # - If the scope identifier is nil, then this is a call to either an
    #   instance or static method of the curent class. In the case of an
    #   instance method, the first argument in the current stack frame is the
    #   "this" pointer, and we should push its value as the first argument to
    #   the next frame.
    # - If the scope identifier is not nil and matches a value on the symbol
    #   table, this is an instance method call. The scope identifier identifies
    #   the instance.
    # - Otherwise, we can assume the scope identifier is the name of another
    #   class.
    if scope_identifier.nil?
      method_prefix = klass.name

      if klass.has_instance_method?(method_call.method_identifier)
        case sv
        when ASTNode::Subroutine::Variant::Constructor,
             ASTNode::Subroutine::Variant::InstanceMethod
          commands << st.resolve("this").push_command
          arg_count += 1
        else
          raise "instance method call outside of instance method: #{method_call}"
        end
      end
    elsif st.includes?(scope_identifier)
      st_entry = st.resolve(scope_identifier)
      method_prefix = st_entry.type

      commands << st_entry.push_command
      arg_count += 1
    else
      method_prefix = scope_identifier
    end

    # Push the remaining arguments onto stack
    method_call.args.each do |e|
      commands += codegen_expression(klass, st, sv, e)
      arg_count += 1
    end

    commands << "call #{method_prefix}.#{method_call.method_identifier} #{arg_count}"
    commands
  end
end
