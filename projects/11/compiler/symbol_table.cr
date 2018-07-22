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

  def clear(var_scope : Compiler::VarScope) : Void
    @decls[var_scope] = {} of String => Int32
  end
end
