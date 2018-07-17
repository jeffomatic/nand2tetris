class Lexer
  enum State
    None
    KeywordOrIdentifier
    IntegerConstant
    StringConstant
    CommentLine
    CommentMulti
  end

  SYMBOLS = [
    '{', '}', '(', ')', '[', ']',
    '.', ',', ';',
    '+', '-', '*', '/', '&', '|', '<', '>', '=', '~',
  ]

  KEYWORDS = [
    "class", "constructor", "method", "function",
    "var", "static", "field",
    "let", "do", "if", "else", "while", "return",

    # Just treat the following like identifiers
    # "int", "boolean", "char", "void",
    # "true", "false", "null",
    # "this",
  ]
end
