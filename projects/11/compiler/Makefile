.PHONY: test-parse helloworld math locals conditional loop

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

loop:
	crystal cmd/codegen/main.cr examples/loop

oop:
	crystal cmd/codegen/main.cr examples/oop

array:
	crystal cmd/codegen/main.cr examples/array

Average:
	crystal cmd/codegen/main.cr ../Average

ComplexArrays:
	crystal cmd/codegen/main.cr ../ComplexArrays

ConvertToBin:
	crystal cmd/codegen/main.cr ../ConvertToBin

Pong:
	crystal cmd/codegen/main.cr ../Pong

Seven:
	crystal cmd/codegen/main.cr ../Seven

Square:
	crystal cmd/codegen/main.cr ../Square
