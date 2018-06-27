ALL_FILES = \
	./ProgramFlow/BasicLoop/BasicLoop.asm	\
	./ProgramFlow/FibonacciSeries/FibonacciSeries.asm \
	./FunctionCalls/SimpleFunction/SimpleFunction.asm \
	./FunctionCalls/NestedCall/NestedCall.asm \
	./FunctionCalls/FibonacciElement/FibonacciElement.asm \
	./FunctionCalls/StaticsTest/StaticsTest.asm

.PHONY: all

all: $(ALL_FILES)

./ProgramFlow/BasicLoop/BasicLoop.asm: vm_translator
	./vm_translator --skip-init ./ProgramFlow/BasicLoop > $@

./ProgramFlow/FibonacciSeries/FibonacciSeries.asm: vm_translator
	./vm_translator --skip-init ./ProgramFlow/FibonacciSeries > $@

./FunctionCalls/SimpleFunction/SimpleFunction.asm: vm_translator
	./vm_translator --skip-init ./FunctionCalls/SimpleFunction > $@

./FunctionCalls/NestedCall/NestedCall.asm: vm_translator
	./vm_translator --skip-init ./FunctionCalls/NestedCall > $@

./FunctionCalls/FibonacciElement/FibonacciElement.asm: vm_translator
	./vm_translator ./FunctionCalls/FibonacciElement > $@

./FunctionCalls/StaticsTest/StaticsTest.asm: vm_translator
	./vm_translator ./FunctionCalls/StaticsTest > $@

vm_translator: vm_translator.cr
	crystal build vm_translator.cr
