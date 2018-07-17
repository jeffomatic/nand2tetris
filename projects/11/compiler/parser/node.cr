require "json"

class Parser
  module Node
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
end

class Parser::Node::Class < Parser::Node::Base
  node_props(
    name : String,
    members : Array(VarDecl),
    subroutines : Array(Subroutine)
  )
end

class Parser::Node::VarDecl < Parser::Node::Base
  enum Scope
    Static
    Field
    Local
  end

  def self.scope_from_string(s : String) : Scope
    case s
    when "static" then return Scope::Static
    when "field"  then return Scope::Field
    when "var"    then return Scope::Local
    else               raise "invalid scope string: #{s}"
    end
  end

  node_props scope : Scope, type : String, names : Array(String)
end

class Parser::Node::Subroutine < Parser::Node::Base
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
    parameters : Array(Node::Parameter),
    locals : Array(Node::VarDecl),
    body : Array(Node::Statement)
  )
end

class Parser::Node::Parameter < Parser::Node::Base
  node_props type : String, name : String
end

abstract class Parser::Node::Statement < Parser::Node::Base
end

class Parser::Node::Assignment < Parser::Node::Statement
  node_props assignee : String, expression : Node::Expression
end

class Parser::Node::Conditional < Parser::Node::Statement
  node_props(
    condition : Node::Expression,
    consequence : Array(Node::Statement),
    alternative : Array(Node::Statement)
  )
end

class Parser::Node::Loop < Parser::Node::Statement
  node_props condition : Node::Expression, body : Array(Node::Statement)
end

class Parser::Node::Do < Parser::Node::Statement
  node_props method_call : Node::MethodCall
end

abstract class Parser::Node::Expression < Parser::Node::Base
end

class Parser::Node::IntegerConstant < Parser::Node::Expression
  node_props value : String
end

class Parser::Node::StringConstant < Parser::Node::Expression
  node_props value : String
end

class Parser::Node::Reference < Parser::Node::Expression
  node_props identifier : String
end

class Parser::Node::BinaryOperation < Parser::Node::Expression
  node_props(
    operator : String,
    left_operand : Node::Expression,
    right_operand : Node::Expression
  )
end

class Parser::Node::UnaryOperation < Parser::Node::Expression
  node_props operator : String, operand : Node::Expression
end

class Parser::Node::MethodCall < Parser::Node::Expression
  node_props(
    scope : String?,
    method : String,
    args : Array(Node::Expression)
  )
end
