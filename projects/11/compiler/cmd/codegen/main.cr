require "../../lexer/lexer"
require "../../parser/parser"
require "../../codegen/codegen"
require "../../util"

tokens = Lexer.lex(STDIN)
nodes = Parser.parse(tokens)
globals = Codegen.collect_globals(nodes)
commands = Codegen.codegen(globals, nodes)
puts commands.join("\n")
