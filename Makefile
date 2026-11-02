# Makefile for CS 375 Pascal parser (Yacc + hand-written C lexer)
#   make parser          build the parser
#   make check           run all test programs and diff against samples
CC     = cc
CFLAGS = -g -Wno-implicit-function-declaration
YACC   = yacc

OBJS = y.tab.o lexanc.o scanner.o printtoken.o pprint.o symtab.o

parser: $(OBJS)
	$(CC) -o parser $(OBJS) -lm

y.tab.c y.tab.h: parse.y token.h parse.h symtab.h lexan.h pprint.h
	$(YACC) parse.y

y.tab.o: y.tab.c
	$(CC) $(CFLAGS) -c y.tab.c

lexanc.o:     lexanc.c token.h lexan.h
scanner.o:    scanner.c token.h lexan.h
printtoken.o: printtoken.c token.h
pprint.o:     pprint.c token.h pprint.h
symtab.o:     symtab.c token.h symtab.h

check: parser
	./tests/check.sh

clean:
	rm -f *.o y.tab.c y.tab.h parser tests/*.out tests/*.diff
