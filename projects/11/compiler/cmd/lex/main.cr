require "../../lexer"

Lexer.lex(STDIN).each { |token| puts token }
