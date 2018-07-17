require "../../lexer/lexer"
require "../../parser/parser"
require "../../util"

tokens = Lexer.lex(STDIN)
nodes = Parser.parse(tokens)
puts Util.pretty_json(nodes)
