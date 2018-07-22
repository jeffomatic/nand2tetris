require "../../lexer"
require "../../parser"
require "../util"

tokens = Lexer.lex(STDIN)
nodes = Parser.parse(tokens)
puts Util.pretty_json(nodes)
