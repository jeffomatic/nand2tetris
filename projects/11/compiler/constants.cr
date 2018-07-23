module Compiler
  enum VarScope
    Static
    Field
    Argument
    Local
  end

  def self.var_scope_from_decl_string(s : String)
    case s
    when "static" then VarScope::Static
    when "field"  then VarScope::Field
    when "var"    then VarScope::Local
    else               raise "invalid scope string: #{s}"
    end
  end

  def self.var_scope_to_segment(vs : VarScope) : String
    case vs
    when VarScope::Static   then "static"
    when VarScope::Field    then "this"
    when VarScope::Argument then "argument"
    when VarScope::Local    then "local"
    else                         raise "invalid scope: #{vs}"
    end
  end
end
