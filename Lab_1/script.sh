#!/bin/bash

bison -d -y -o y.tab.c 22241086_24241194.y
echo 'Generated the parser C file and header file'
g++ -w -fpermissive -c -o y.o y.tab.c
echo 'Generated the parser object file'
flex -o lex.yy.c 22241086_24241194.l
echo 'Generated the scanner C file'
g++ -w -fpermissive -c -o l.o lex.yy.c
echo 'Generated the scanner object file'
g++ -w -fpermissive y.o l.o -o a.exe
echo 'All ready, running'
./a.exe input.txt