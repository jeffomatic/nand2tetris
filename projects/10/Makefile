SOURCE_FILES = $(shell find ./ -type f -name '*.jack')
LEX_FILES = $(SOURCE_FILES:.jack=.lex.xml)

.PHONY: lex

lex: $(LEX_FILES)

%.lex.xml: lexer.cr
	cat $(@:.lex.xml=.jack) | crystal lexer.cr > $@
	../../tools/TextComparer.sh $(@:.lex.xml=T.xml) $@
