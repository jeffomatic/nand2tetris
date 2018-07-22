.PHONY: lex parse test-parse test-codegen

lex: $(LEX_FILES)

parse: $(PARSE_FILES)

test-parse:
	cat ./test.jack | crystal cmd/parse/main.cr

helloworld:
	crystal cmd/codegen/main.cr jack/helloworld
