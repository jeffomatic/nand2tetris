.PHONY: test-parse helloworld math locals conditional

test-parse:
	cat ./examples/test-parse/test.jack | crystal cmd/parse/main.cr

helloworld:
	crystal cmd/codegen/main.cr examples/helloworld

math:
	crystal cmd/codegen/main.cr examples/math

locals:
	crystal cmd/codegen/main.cr examples/locals

conditional:
	crystal cmd/codegen/main.cr examples/conditional
