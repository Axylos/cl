#Copyright (C) 2007-2009, Bruce Ediger
#
#   This file is part of cl.
#
#   cl is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   cl is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with cl; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

all:
	@echo "Try one of these:"
	@echo "make cc"   "- very generic"
	@echo "make gnu"  "- all GNU"
	@echo "make coverage"  "- all GNU, with gcov options on"
	@echo "make lcc"  "- lcc C compiler and yacc"
	@echo "make tcc"  "- tcc C compiler and yacc"
	@echo "make pcc"  "- pcc C compiler and yacc"
 
cc:
	make CC=cc YACC='yacc -d -v' LEX=lex CFLAGS='-I. -g' build
gnu:
	make CC=gcc YACC='bison -d -b y' LEX=flex CFLAGS='-I. -g  -Wall  ' build
mudflap:
	make CC=gcc YACC='bison -d -b y' LEX=flex CFLAGS='-I. -g -fmudflap -Wall' LIBS=-lmudflap build
coverage:
	make CC=gcc YACC='bison -d -b y' LEX=flex CFLAGS='-I. -fprofile-arcs -ftest-coverage' build
profile:
	make CC=gcc YACC='bison -d -b y' LEX=flex CFLAGS='-I. -pg' build
lcc:
	make CC=lcc YACC='yacc -d -v' CFLAGS='-I.' build
tcc:
	make CC='tcc -Wall' YACC='yacc -d -v' CFLAGS='-I.' build
pcc:
	make CC=pcc YACC='yacc -d -v' LEX=lex CFLAGS='-I. -g' build
clang:
	make CC=clang  YACC='yacc -d -v -t ' LEX=lex CFLAGS='-I. -g -Wall -O3 ' build

special:
	make CC=gcc YACC='yacc -d -v' LEX=flex sbuild

sbuild:
	make CFLAGS='-Wunused -Wpointer-arith -Wunused-parameter -Wstrict-prototypes -Wmissing-prototypes -Wpointer-arith -Wreturn-type -Wcast-qual -Wswitch -Wshadow -Wcast-align -Wwrite-strings -Wchar-subscripts -Winline -Wnested-externs -Wshadow -Wsequence-point -Wnonnull -Wstrict-aliasing -Wswitch -Wswitch-enum -O2 -g  -I.'  build

build: cl

OBJS = node.o atom.o hashtable.o graph.o arena.o abbreviations.o \
	spine_stack.o bracket_abstraction.o buffer.o cycle_detector.o \
	aho_corasick.o cb.o algorithm_d.o

y.tab.c y.tab.h: grammar.y
	$(YACC) grammar.y

lex.yy.c: lex.l
	$(LEX) lex.l

lex.yy.o: lex.yy.c y.tab.h atom.h hashtable.h node.h

y.tab.o: y.tab.c y.tab.h node.h atom.h hashtable.h graph.h \
	abbreviations.h bracket_abstraction.h

arena.o: arena.c arena.h
atom.o: atom.c atom.h hashtable.h
bracket_abstraction.o: bracket_abstraction.c bracket_abstraction.h node.h graph.h buffer.h
buffer.o: buffer.c buffer.h
cycle_detector.o: cycle_detector.c node.h graph.h buffer.h cycle_detector.h
graph.o: graph.c graph.h node.h buffer.h spine_stack.h cycle_detector.h \
	aho_corasick.h algorithm_d.h
hashtable.o: hashtable.c hashtable.h node.h abbreviations.h
node.o: node.c node.h arena.h
spine_stack.o: spine_stack.c spine_stack.h
cb.o: cb.c cb.h
aho_corasick.o: aho_corasick.c  aho_corasick.h cb.h
algorithm_d.o: algorithm_d.c algorithm_d.h node.h buffer.h aho_corasick.h

cl: y.tab.o lex.yy.o $(OBJS)
	$(CC) $(CFLAGS) -g -o cl y.tab.o lex.yy.o $(OBJS) $(LIBS)

tests:  gnu runtests
	-./runtests

fuzz: gnu clfuzz
	-rm -rf fuzz.in
	./clfuzz 20 25 > fuzz.in
	./cl -T 10 < fuzz.in

clean:
	-rm -rf cl
	-rm y.tab.c y.tab.h lex.yy.c y.output
	-rm -rf y.tab.o lex.yy.o $(OBJS)
	-rm -rf core *.a *.o *.bb *.bbg .da
	-rm -rf *.gcda *.gcno
	-rm -f tests.output/* fuzz.in
