#!/bin/bash

# Use input.c when no file name is given to the script.
INPUT_FILE=${1:-input.c}

# 1. Generate parser files from the Yacc file.
yacc -d -y --debug --verbose 24241172_24241333.y
if [ $? -ne 0 ]; then
    echo "Yacc generation failed"
    exit 1
fi

# 2. Compile the parser.
g++ -w -c -o y.o y.tab.c
if [ $? -ne 0 ]; then
    echo "Parser compilation failed"
    exit 1
fi

# 3. Generate scanner file from the Lex file.
flex 24241172_24241333.l
if [ $? -ne 0 ]; then
    echo "Flex generation failed"
    exit 1
fi

# 4. Compile the scanner.
g++ -fpermissive -w -c -o l.o lex.yy.c
if [ $? -ne 0 ]; then
    echo "Scanner compilation failed"
    exit 1
fi

# 5. Link parser and scanner.
g++ y.o l.o -o compiler
if [ $? -ne 0 ]; then
    echo "Linking failed"
    exit 1
fi

# 6. Run the compiler with the selected C input file.
echo "Running semantic analyzer on $INPUT_FILE"
./compiler "$INPUT_FILE"

echo "----- LOG FILE -----"
cat 24241172_24241333_log.txt

echo "----- ERROR FILE -----"
cat 24241172_24241333_error.txt
