SOURCE_FILES = $(shell find . -name *.vm)
ASM_FILES = $(SOURCE_FILES:.vm=.asm)

all: $(ASM_FILES)

%.asm: ./vm_translator.cr
	crystal ./vm_translator.cr $(@:.asm=.vm) > $@
