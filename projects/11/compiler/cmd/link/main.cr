require "file"
require "../../lexer/lexer"
require "../../parser/parser"
require "../../codegen/codegen"
require "../../util"

tokens = Lexer.lex(STDIN)
nodes = Parser.parse(tokens)
globals = Codegen.collect_globals(nodes)
puts Codegen.codegen(globals, nodes).join("\n")

