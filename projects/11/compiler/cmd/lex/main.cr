require "../../lexer/lexer"

Lexer.lex(STDIN).each { |token| puts token }
