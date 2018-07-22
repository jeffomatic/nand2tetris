.PHONY: test-parse helloworld math locals

test-parse:
	cat ./examples/test-parse/test.jack | crystal cmd/parse/main.cr

helloworld:
	crystal cmd/codegen/main.cr jack/helloworld

math:
	crystal cmd/codegen/main.cr jack/math

locals:
	crystal cmd/codegen/main.cr jack/locals
