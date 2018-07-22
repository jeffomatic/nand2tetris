require "./ast_node"

class SymbolTable
  class Entry
    def_clone
    getter var_scope, type, identifier, offset

    def initialize(
      *,
      @var_scope : Compiler::VarScope,
      @type : String,
      @identifier : String,
      @offset : Int32
    )
    end

    def pop_command
      "pop #{Compiler.var_scope_to_segment(@var_scope)} #{@offset}"
    end

    def push_command
      "push #{Compiler.var_scope_to_segment(@var_scope)} #{@offset}"
    end
  end

  def_clone

  def initialize(klass : ASTNode::Class)
    @entries_by_var_scope = {
      Compiler::VarScope::Local    => ({} of String => Entry),
      Compiler::VarScope::Argument => ({} of String => Entry),
      Compiler::VarScope::Field    => ({} of String => Entry),
      Compiler::VarScope::Static   => ({} of String => Entry),
    }

    klass.members.each do |member|
      member.names.each do |n|
        declare(
          var_scope: member.var_scope,
          type: member.type,
          identifier: n
        )
      end
    end
  end

  def declare(
    *,
    var_scope : Compiler::VarScope,
    type : String,
    identifier : String
  )
    table = @entries_by_var_scope[var_scope]
    table[identifier] = Entry.new(
      var_scope: var_scope,
      type: type,
      identifier: identifier,
      offset: table.size
    )
  end

  def resolve(identifier : String) : Entry
    @entries_by_var_scope.each do |var_scope, entries|
      return entries[identifier] if entries.has_key?(identifier)
    end

    raise "undeclared variable: #{identifier}"
  end

  def clear(var_scope : Compiler::VarScope) : Void
    @entries_by_var_scope[var_scope] = {} of String => Entry
  end
end
