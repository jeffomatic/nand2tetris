require "json"
require "./constants"

module ASTNode
  abstract class Base
    macro node_props(*props)
      {% for p in props %}
        {% raise "invalid type declaration: #{p}" if !p.is_a?(TypeDeclaration) %}
        getter {{p}}
      {% end %}

      def initialize(
        *,
        {% for p in props %}
          @{{p.var.id}} : {{p.type}},
        {% end %}
      )
      end

      def to_h
        super.merge(
          {% for p in props %}
            {{p.var.id}}: {{p.var.id}},
          {% end %}
        )
      end
    end

    def to_h
      {
        node_type: self.class.name,
      }
    end

    def to_json(json : JSON::Builder)
      to_h.to_json(json)
    end
  end
end

class ASTNode::Class < ASTNode::Base
  node_props(
    name : String,
    members : Array(VarDecl),
    subroutines : Array(Subroutine)
  )

  def count_instance_vars
    members.reduce(0) do |memo, m|
      next memo unless m.var_scope == Compiler::VarScope::Field
      memo += m.names.size
    end
  end

  def has_instance_method?(identifier : String) : Bool
    subroutines.any? do |sub|
      sub.name == identifier &&
        sub.variant == ASTNode::Subroutine::Variant::InstanceMethod
    end
  end
end

class ASTNode::VarDecl < ASTNode::Base
  node_props(
    var_scope : Compiler::VarScope,
    type : String,
    names : Array(String)
  )
end

class ASTNode::Subroutine < ASTNode::Base
  enum Variant
    Constructor
    InstanceMethod
    ClassMethod
  end

  def self.variant_from_string(s : String) : Variant
    case s
    when "constructor" then return Variant::Constructor
    when "method"      then return Variant::InstanceMethod
    when "function"    then return Variant::ClassMethod
    else                    raise "invalid variant string: #{s}"
    end
  end

  node_props(
    variant : Variant,
    return_type : String,
    name : String,
    parameters : Array(ASTNode::Parameter),
    locals : Array(ASTNode::VarDecl),
    body : Array(ASTNode::Statement)
  )
end

class ASTNode::Parameter < ASTNode::Base
  node_props type : String, name : String
end

abstract class ASTNode::Statement < ASTNode::Base
end

class ASTNode::Assignment < ASTNode::Statement
  node_props(
    assignee : String,
    offset_expression : ASTNode::Expression?,
    value_expression : ASTNode::Expression
  )
end

class ASTNode::Conditional < ASTNode::Statement
  node_props(
    condition : ASTNode::Expression,
    consequence : Array(ASTNode::Statement),
    alternative : Array(ASTNode::Statement)
  )
end

class ASTNode::Loop < ASTNode::Statement
  node_props condition : ASTNode::Expression, body : Array(ASTNode::Statement)
end

class ASTNode::Do < ASTNode::Statement
  node_props method_call : ASTNode::MethodCall
end

class ASTNode::Return < ASTNode::Statement
  node_props expression : ASTNode::Expression?
end

abstract class ASTNode::Expression < ASTNode::Base
end

class ASTNode::IntegerConstant < ASTNode::Expression
  node_props value : String
end

class ASTNode::StringConstant < ASTNode::Expression
  node_props value : String
end

class ASTNode::BooleanConstant < ASTNode::Expression
  node_props value : Bool
end

class ASTNode::NullConstant < ASTNode::Expression
end

class ASTNode::Reference < ASTNode::Expression
  node_props identifier : String
end

class ASTNode::BinaryOperation < ASTNode::Expression
  node_props(
    operator : String,
    left_operand : ASTNode::Expression,
    right_operand : ASTNode::Expression
  )
end

class ASTNode::UnaryOperation < ASTNode::Expression
  node_props operator : String, operand : ASTNode::Expression
end

class ASTNode::ArrayAccess < ASTNode::Expression
  node_props(
    varname : String,
    offset_expression : ASTNode::Expression
  )
end

class ASTNode::MethodCall < ASTNode::Expression
  node_props(
    scope_identifier : String?,
    method_identifier : String,
    args : Array(ASTNode::Expression)
  )
end
