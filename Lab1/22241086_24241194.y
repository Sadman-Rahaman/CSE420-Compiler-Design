############### Header Section ################
%{

#include <bits/stdc++.h>

#include "symbol_info.h" ########### gives parser access to the symbol_info class

#define YYSTYPE symbol_info* ######### connects directly to what we discussed in .l file.Yacc file receives that as $1, $2, etc

int yyparse(void);
int yylex(void);

extern FILE *yyin;

ofstream outlog;

int line_num = 1; ################# current line while parsing.
int total_lines = 0; ############ Final number of lines in the entire input file.
#######################################################################################################################


static void log_rule(const string &rule, const string &snippet) ######### 1st helper function
{
    outlog << "At line no: " << line_num  << " " 
            << rule << endl << endl;
    outlog << snippet << endl << endl; ######### writes the actual source-code portion.
}

static int count_total_lines(const string &filename)  ##############  2nd helper function. 
################ Open the input file and count how many lines it contains.
{
    ifstream fin(filename); ######## fin opens input.txt for reading.
    if (!fin.is_open()) ######### Check whether it opened successfully. if not then 0.
    {
        return 0;
    }

    int count = 0;
    string line;
    while (getline(fin, line)) #########  getline() reads one complete line from the file.
    {
        ++count;
    }
    return count;
}

void yyerror(char *s) ########## This is called when Yacc encounters something that doesn't match the grammar. simply output your own error message.
{
    outlog << "Line no " << line_num << ": Syntax error" << endl << endl;
}

%}


###################### token declarations that .l file returns.

%token IF ELSE FOR WHILE DO INT FLOAT VOID CONTINUE BREAK CHAR DOUBLE CASE SWITCH DEFAULT GOTO RETURN PRINTLN
%token ADDOP MULOP INCOP DECOP RELOP ASSIGNOP LOGICOP NOT
%token LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA COLON SEMICOLON
%token ID CONST_INT CONST_FLOAT

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

start
    : program
    {
        log_rule("start : program", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "start");
    }
    ;

program
    : program unit
    {
        string snippet = $1->getnameofsymbol() + "\n" + $2->getnameofsymbol();
        log_rule("program : program unit", snippet);
        $$ = new symbol_info(snippet, "program");
    }
    | unit
    {
        log_rule("program : unit", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "program");
    }
    ;

unit
    : variable_decl
    {
        log_rule("unit : variable_decl", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "unit");
    }
    | func_definition
    {
        log_rule("unit : func_definition", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "unit");
    }
    ;

variable_decl
    : type_specifier declaration_list SEMICOLON
    {
        string snippet = $1->getnameofsymbol() + " " + $2->getnameofsymbol() + ";";
        log_rule("variable_decl : type_specifier declaration_list SEMICOLON", snippet);
        $$ = new symbol_info(snippet, "variable_decl");
    }
    ;

type_specifier ######### translates the token into the corresponding source string and labels it as a type_specifier.
    : INT
    {
        log_rule("type_specifier : INT", "int");
        $$ = new symbol_info("int", "type_specifier");
    }
    | FLOAT
    {
        log_rule("type_specifier : FLOAT", "float");
        $$ = new symbol_info("float", "type_specifier");
    }
    | VOID
    {
        log_rule("type_specifier : VOID", "void");
        $$ = new symbol_info("void", "type_specifier");
    }
    | CHAR
    {
        log_rule("type_specifier : CHAR", "char");
        $$ = new symbol_info("char", "type_specifier");
    }
    ;

declaration_list
    : declaration_list COMMA ID
    {
        string snippet = $1->getnameofsymbol() + "," + $3->getnameofsymbol();
        log_rule("declaration_list : declaration_list COMMA ID", snippet);
        $$ = new symbol_info(snippet, "declaration_list");
    }
    | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
    {
        string snippet = $1->getnameofsymbol() + "," + $3->getnameofsymbol() + "[" + $5->getnameofsymbol() + "]";
        log_rule("declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD", snippet);
        $$ = new symbol_info(snippet, "declaration_list");
    }
    | ID
    {
        log_rule("declaration_list : ID", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "declaration_list");
    }
    | ID LTHIRD CONST_INT RTHIRD
    {
        string snippet = $1->getnameofsymbol() + "[" + $3->getnameofsymbol() + "]";
        log_rule("declaration_list : ID LTHIRD CONST_INT RTHIRD", snippet);
        $$ = new symbol_info(snippet, "declaration_list");
    }
    ;

func_definition
    : type_specifier ID LPAREN param_list RPAREN compound_statement
    {
        string snippet = $1->getnameofsymbol() + " " + $2->getnameofsymbol() + "(" + $4->getnameofsymbol() + ")\n" + $6->getnameofsymbol();
        log_rule("func_definition : type_specifier ID LPAREN param_list RPAREN compound_statement", snippet);
        $$ = new symbol_info(snippet, "func_definition");
    }
    | type_specifier ID LPAREN RPAREN compound_statement
    {
        string snippet = $1->getnameofsymbol() + " " + $2->getnameofsymbol() + "()\n" + $5->getnameofsymbol();
        log_rule("func_definition : type_specifier ID LPAREN RPAREN compound_statement", snippet);
        $$ = new symbol_info(snippet, "func_definition");
    }
    ;

param_list
    : param_list COMMA type_specifier ID
    {
        string snippet = $1->getnameofsymbol() + "," + $3->getnameofsymbol() + " " + $4->getnameofsymbol();
        log_rule("param_list : param_list COMMA type_specifier ID", snippet);
        $$ = new symbol_info(snippet, "param_list");
    }
    | param_list COMMA type_specifier
    {
        string snippet = $1->getnameofsymbol() + "," + $3->getnameofsymbol();
        log_rule("param_list : param_list COMMA type_specifier", snippet);
        $$ = new symbol_info(snippet, "param_list");
    }
    | type_specifier ID
    {
        string snippet = $1->getnameofsymbol() + " " + $2->getnameofsymbol();
        log_rule("param_list : type_specifier ID", snippet);
        $$ = new symbol_info(snippet, "param_list");
    }
    | type_specifier
    {
        log_rule("param_list : type_specifier", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "param_list");
    }
    | VOID
    {
        log_rule("param_list : VOID", "void");
        $$ = new symbol_info("void", "param_list");
    }
    ;

compound_statement
    : LCURL statements RCURL
    {
        string snippet = "{\n" + $2->getnameofsymbol() + "\n}";
        log_rule("compound_statement : LCURL statements RCURL", snippet);
        $$ = new symbol_info(snippet, "compound_statement");
    }
    | LCURL RCURL
    {
        log_rule("compound_statement : LCURL RCURL", "{}");
        $$ = new symbol_info("{}", "compound_statement");
    }
    ;

statements
    : statements statement
    {
        string snippet = $1->getnameofsymbol();
        if (!snippet.empty()) ############ prevents from adding unnecessary newline before the first statement.
        {
            snippet += "\n";
        }
        snippet += $2->getnameofsymbol();
        log_rule("statements : statements statement", snippet);
        $$ = new symbol_info(snippet, "statements");
    }
    | statement
    {
        log_rule("statements : statement", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "statements");
    }
    ;

statement
    : expression_statement
    {
        log_rule("statement : expression_statement", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "statement");
    }
    | compound_statement
    {
        log_rule("statement : compound_statement", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "statement");
    }
    | FOR LPAREN expression_statement expression_statement expression RPAREN statement
    {
        string snippet = "for(" + $3->getnameofsymbol() + $4->getnameofsymbol() + $5->getnameofsymbol() + ")\n" + $7->getnameofsymbol();
        log_rule("statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement", snippet);
        $$ = new symbol_info(snippet, "statement");
    }
    | IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
    {
        string snippet = "if(" + $3->getnameofsymbol() + ")\n" + $5->getnameofsymbol();
        log_rule("statement : IF LPAREN expression RPAREN statement", snippet);
        $$ = new symbol_info(snippet, "statement");
    }
    | IF LPAREN expression RPAREN statement ELSE statement
    {
        string snippet = "if(" + $3->getnameofsymbol() + ")\n" + $5->getnameofsymbol() + "\nelse\n" + $7->getnameofsymbol();
        log_rule("statement : IF LPAREN expression RPAREN statement ELSE statement", snippet);
        $$ = new symbol_info(snippet, "statement");
    }
    | WHILE LPAREN expression RPAREN statement
    {
        string snippet = "while(" + $3->getnameofsymbol() + ")\n" + $5->getnameofsymbol();
        log_rule("statement : WHILE LPAREN expression RPAREN statement", snippet);
        $$ = new symbol_info(snippet, "statement");
    }
    | RETURN expression SEMICOLON
    {
        string snippet = "return " + $2->getnameofsymbol() + ";";
        log_rule("statement : RETURN expression SEMICOLON", snippet);
        $$ = new symbol_info(snippet, "statement");
    }
    | PRINTLN LPAREN ID RPAREN SEMICOLON
    {
        string snippet = "printf(" + $3->getnameofsymbol() + ");";
        log_rule("statement : PRINTLN LPAREN ID RPAREN SEMICOLON", snippet);
        $$ = new symbol_info(snippet, "statement");
    }
    ;

expression_statement
    : SEMICOLON
    {
        log_rule("expression_statement : SEMICOLON", ";");
        $$ = new symbol_info(";", "expression_statement");
    }
    | expression SEMICOLON
    {
        string snippet = $1->getnameofsymbol() + ";";
        log_rule("expression_statement : expression SEMICOLON", snippet);
        $$ = new symbol_info(snippet, "expression_statement");
    }
    ;

expression
    : logic_expression
    {
        log_rule("expression : logic_expression", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "expression");
    }
    | variable ASSIGNOP logic_expression
    {
        string snippet = $1->getnameofsymbol() + "=" + $3->getnameofsymbol();
        log_rule("expression : variable ASSIGNOP logic_expression", snippet);
        $$ = new symbol_info(snippet, "expression");
    }
    ;

logic_expression
    : rel_expression
    {
        log_rule("logic_expression : rel_expression", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "logic_expression");
    }
    | logic_expression LOGICOP rel_expression
    {
        string snippet = $1->getnameofsymbol() + $2->getnameofsymbol() + $3->getnameofsymbol();
        log_rule("logic_expression : logic_expression LOGICOP rel_expression", snippet);
        $$ = new symbol_info(snippet, "logic_expression");
    }
    ;

rel_expression
    : simple_expression
    {
        log_rule("rel_expression : simple_expression", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "rel_expression");
    }
    | simple_expression RELOP simple_expression
    {
        string snippet = $1->getnameofsymbol() + $2->getnameofsymbol() + $3->getnameofsymbol();
        log_rule("rel_expression : simple_expression RELOP simple_expression", snippet);
        $$ = new symbol_info(snippet, "rel_expression");
    }
    ;

simple_expression
    : simple_expression ADDOP term
    {
        string snippet = $1->getnameofsymbol() + $2->getnameofsymbol() + $3->getnameofsymbol();
        log_rule("simple_expression : simple_expression ADDOP term", snippet);
        $$ = new symbol_info(snippet, "simple_expression");
    }
    | term
    {
        log_rule("simple_expression : term", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "simple_expression");
    }
    ;

term
    : term MULOP unary_expression
    {
        string snippet = $1->getnameofsymbol() + $2->getnameofsymbol() + $3->getnameofsymbol();
        log_rule("term : term MULOP unary_expression", snippet);
        $$ = new symbol_info(snippet, "term");
    }
    | unary_expression
    {
        log_rule("term : unary_expression", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "term");
    }
    ;

unary_expression
    : ADDOP unary_expression
    {
        string snippet = $1->getnameofsymbol() + $2->getnameofsymbol();
        log_rule("unary_expression : ADDOP unary_expression", snippet);
        $$ = new symbol_info(snippet, "unary_expression");
    }
    | NOT unary_expression
    {
        string snippet = "!" + $2->getnameofsymbol();
        log_rule("unary_expression : NOT unary_expression", snippet);
        $$ = new symbol_info(snippet, "unary_expression");
    }
    | factor_info
    {
        log_rule("unary_expression : factor", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "unary_expression");
    }
    ;

factor_info
    : factor
    {
        log_rule("factor_info : factor", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "factor_info");
    }
    ;

factor
    : variable
    {
        log_rule("factor : variable", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "factor");
    }
    | variable INCOP
    {
        string snippet = $1->getnameofsymbol() + "++";
        log_rule("factor : variable INCOP", snippet);
        $$ = new symbol_info(snippet, "factor");
    }
    | variable DECOP
    {
        string snippet = $1->getnameofsymbol() + "--";
        log_rule("factor : variable DECOP", snippet);
        $$ = new symbol_info(snippet, "factor");
    }
    | ID LPAREN argument_list RPAREN
    {
        string snippet = $1->getnameofsymbol() + "(" + $3->getnameofsymbol() + ")";
        log_rule("factor : ID LPAREN argument_list RPAREN", snippet);
        $$ = new symbol_info(snippet, "factor");
    }
    | ID LPAREN RPAREN
    {
        string snippet = $1->getnameofsymbol() + "()";
        log_rule("factor : ID LPAREN RPAREN", snippet);
        $$ = new symbol_info(snippet, "factor");
    }
    | LPAREN expression RPAREN
    {
        string snippet = "(" + $2->getnameofsymbol() + ")";
        log_rule("factor : LPAREN expression RPAREN", snippet);
        $$ = new symbol_info(snippet, "factor");
    }
    | CONST_INT
    {
        log_rule("factor : CONST_INT", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "factor");
    }
    | CONST_FLOAT
    {
        log_rule("factor : CONST_FLOAT", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "factor");
    }
    ;

variable
    : ID
    {
        log_rule("variable : ID", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "variable");
    }
    | ID LTHIRD expression RTHIRD
    {
        string snippet = $1->getnameofsymbol() + "[" + $3->getnameofsymbol() + "]";
        log_rule("variable : ID LTHIRD expression RTHIRD", snippet);
        $$ = new symbol_info(snippet, "variable");
    }
    ;

argument_list
    : arguments
    {
        log_rule("argument_list : arguments", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "argument_list");
    }
    | 
    {
        $$ = new symbol_info("", "argument_list");
    }
    ;

arguments
    : arguments COMMA logic_expression
    {
        string snippet = $1->getnameofsymbol() + "," + $3->getnameofsymbol();
        log_rule("arguments : arguments COMMA logic_expression", snippet);
        $$ = new symbol_info(snippet, "arguments");
    }
    | logic_expression
    {
        log_rule("arguments : logic_expression", $1->getnameofsymbol());
        $$ = new symbol_info($1->getnameofsymbol(), "arguments");
    }
    ;

%%

int main(int argc, char *argv[])
{
    if (argc != 2)
    {
        cout << "Please provide input file name" << endl;
        return 0;
    }

    yyin = fopen(argv[1], "r");
    if (yyin == NULL)
    {
        cout << "Couldn't open file" << endl;
        return 0;
    }

    total_lines = count_total_lines(argv[1]);

    outlog.open("22241086_24241194_log.txt", ios::trunc);
    yyparse();
    outlog << "Total lines: " << total_lines << endl;
    outlog.close();

    fclose(yyin);
    return 0;
}