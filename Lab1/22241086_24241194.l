%option noyywrap



############################ C section ############################
%{
#include <bits/stdc++.h>

#include "symbol_info.h" ####### symbol table access kore 

#define YYSTYPE symbol_info* ########### symbol table point kore.

#include "y.tab.h"

extern YYSTYPE yylval; ########### extern symbol_info* yylval;

using namespace std;

extern int line_num; ###########
extern ofstream outlog; ########### These variables exist somewhere else; I want to use them here

static void log_simple_token(const string &token_name) ################# 1st helper function
{ ################# Instead of repeating Line no, token, Lexeme for every keyword,i created one reusable function.This function only handles logging/output.
    outlog << "Line no " << line_num 
    << ": Token <" << token_name 
    << "> Lexeme " << yytext 
    << " found" << endl << endl;
}

static void log_value_token(const string &token_name, const string &value_type) ################# 2nd helper function
{ ################ It creates the symbol_info object and puts its pointer into yylval.
    yylval = new symbol_info(string(yytext), value_type);
    outlog << "Line no " << line_num 
    << ": Token <" << token_name 
    << "> Lexeme " << yytext 
    << " found" << endl << endl;
}

%}




delim        [ \t\v\r]
ws           {delim}+
newline      \n+

letter_      [A-Za-z_]
digit        [0-9]
id           {letter_}({letter_}|{digit})*
integer      {digit}+
floating     ({digit}+\.{digit}*([Ee][+-]?{digit}+)?|\.{digit}+([Ee][+-]?{digit}+)?|{digit}+[Ee][+-]?{digit}+)

%%
{ws}                 { }
{newline}            { line_num += yyleng; }

"if"                { log_simple_token("IF"); return IF; }
"else"              { log_simple_token("ELSE"); return ELSE; }
"for"               { log_simple_token("FOR"); return FOR; }
"while"             { log_simple_token("WHILE"); return WHILE; }
"do"                { log_simple_token("DO"); return DO; }
"int"               { log_simple_token("INT"); return INT; }
"float"             { log_simple_token("FLOAT"); return FLOAT; }
"continue"          { log_simple_token("CONTINUE"); return CONTINUE; }
"break"             { log_simple_token("BREAK"); return BREAK; }
"char"              { log_simple_token("CHAR"); return CHAR; }
"double"            { log_simple_token("DOUBLE"); return DOUBLE; }
"case"              { log_simple_token("CASE"); return CASE; }
"void"              { log_simple_token("VOID"); return VOID; }
"switch"            { log_simple_token("SWITCH"); return SWITCH; }
"default"           { log_simple_token("DEFAULT"); return DEFAULT; }
"goto"              { log_simple_token("GOTO"); return GOTO; }
"return"            { log_simple_token("RETURN"); return RETURN; }
"printf"            { log_simple_token("PRINTLN"); return PRINTLN; }

"++"                { log_simple_token("INCOP"); return INCOP; }
"--"                { log_simple_token("DECOP"); return DECOP; }
"<="                { log_simple_token("RELOP"); return RELOP; }
">="                { log_simple_token("RELOP"); return RELOP; }
"=="                { log_simple_token("RELOP"); return RELOP; }
"!="                { log_simple_token("RELOP"); return RELOP; }
"&&"                { log_simple_token("LOGICOP"); return LOGICOP; }
"||"                { log_simple_token("LOGICOP"); return LOGICOP; }
"<"                 { log_simple_token("RELOP"); return RELOP; }
">"                 { log_simple_token("RELOP"); return RELOP; }
"="                 { log_simple_token("ASSIGNOP"); return ASSIGNOP; }
"!"                 { log_simple_token("NOT"); return NOT; }

"+"|"-"            { log_simple_token("ADDOP"); return ADDOP; }
"*"|"/"|"%"        { log_simple_token("MULOP"); return MULOP; }

"("                 { log_simple_token("LPAREN"); return LPAREN; }
")"                 { log_simple_token("RPAREN"); return RPAREN; }
"{"                 { log_simple_token("LCURL"); return LCURL; }
"}"                 { log_simple_token("RCURL"); return RCURL; }
"["                 { log_simple_token("LTHIRD"); return LTHIRD; }
"]"                 { log_simple_token("RTHIRD"); return RTHIRD; }
","                 { log_simple_token("COMMA"); return COMMA; }
":"                 { log_simple_token("COLON"); return COLON; }
";"                 { log_simple_token("SEMICOLON"); return SEMICOLON; }

{floating}           { log_value_token("CONST_FLOAT", "CONST_FLOAT"); return CONST_FLOAT; }
{integer}            { log_value_token("CONST_INT", "CONST_INT"); return CONST_INT; }
{id}                 { log_value_token("ID", "ID"); return ID; }

<<EOF>>              { return 0; }
########### When Flex reaches the end of input.txt, it returns: 0, which tells Yacc: There are no more tokens.
%%