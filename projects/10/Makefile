SOURCE_FILES = $(shell find ./ -type f -name '*.jack')
LEX_FILES = $(SOURCE_FILES:.jack=.lex.xml)
PARSE_FILES = $(SOURCE_FILES:.jack=.parse.xml)

.PHONY: lex parse

lex: $(LEX_FILES)

parse: $(PARSE_FILES)

%.lex.xml: lexer.cr
	cat $(@:.lex.xml=.jack) | crystal lexer.cr > $@
	../../tools/TextComparer.sh $(@:.lex.xml=T.xml) $@

%.parse.xml: %T.xml parser.cr
	cat $(@:.parse.xml=T.xml) | crystal parser.cr > $@
	../../tools/TextComparer.sh $(@:.parse.xml=.xml) $@
