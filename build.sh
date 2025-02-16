#!/bin/bash

rm -f parser.tab.c parser.tab.h lex.yy.c

bison -d parser.y

flex lexer.l

gcc -o compiler lex.yy.c parser.tab.c -lfl