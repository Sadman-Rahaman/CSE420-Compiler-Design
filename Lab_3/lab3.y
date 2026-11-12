%{

#include "symbol_table.h"

#define YYSTYPE symbol_info*

extern FILE *yyin;
int yyparse(void);
int yylex(void);
extern YYSTYPE yylval;

symbol_table *table;

int lines = 1;
int error_count = 0;

ofstream outlog;
ofstream outerror;

string var_type;
string func_name, func_ret_type;
vector<pair<string,string>> param_list_v;
bool func_scope = false;



void semantic_error(string message)
{
    outlog << "At line no: " << lines << " " << message << endl << endl;
    outerror << "At line no: " << lines << " " << message << endl << endl;
    error_count++;
}


void copy_type(symbol_info *to, symbol_info *from)
{
    to->set_data_type(from->get_data_type());
    to->set_argument_types(from->get_argument_types());
    to->set_void_function_call(from->is_void_function_call());

    if (from->has_constant_value())
        to->set_constant_value(from->get_constant_value());
    else
        to->clear_constant_value();
}


bool is_numeric_type(string type)
{
    return type == "char" || type == "int" || type == "float" || type == "double";
}


int type_rank(string type)
{
    if (type == "char") return 0;
    if (type == "int") return 1;
    if (type == "float") return 2;
    if (type == "double") return 3;
    return -1;
}


string arithmetic_type(string left_type, string right_type)
{
    if (left_type == "error" || right_type == "error")
        return "error";

    if (!is_numeric_type(left_type) || !is_numeric_type(right_type))
        return "error";

    if (left_type == "double" || right_type == "double")
        return "double";
    if (left_type == "float" || right_type == "float")
        return "float";

    
    return "int";
}

bool is_zero(symbol_info *symbol)
{
    return symbol->has_constant_value() && fabs(symbol->get_constant_value()) < 1e-12;
}



void set_binary_constant(symbol_info *result, symbol_info *left, string op, symbol_info *right)
{
    result->clear_constant_value();

    if (!left->has_constant_value() || !right->has_constant_value())
        return;

    double a = left->get_constant_value();
    double b = right->get_constant_value();

    if (op == "+") result->set_constant_value(a + b);
    else if (op == "-") result->set_constant_value(a - b);
    else if (op == "*") result->set_constant_value(a * b);
    else if (op == "/" && fabs(b) >= 1e-12)
    {
        if (left->get_data_type() == "int" && right->get_data_type() == "int")
            result->set_constant_value((long long)a / (long long)b);
        else
            result->set_constant_value(a / b);
    }
    else if (op == "%" && fabs(b) >= 1e-12) result->set_constant_value((long long)a % (long long)b);
    else if (op == "<") result->set_constant_value(a < b);
    else if (op == ">") result->set_constant_value(a > b);
    else if (op == "<=") result->set_constant_value(a <= b);
    else if (op == ">=") result->set_constant_value(a >= b);
    else if (op == "==") result->set_constant_value(a == b);
    else if (op == "!=") result->set_constant_value(a != b);
    else if (op == "&&") result->set_constant_value((a != 0) && (b != 0));
    else if (op == "||") result->set_constant_value((a != 0) || (b != 0));
}



bool contains_void_function(symbol_info *symbol)
{
    return symbol->is_void_function_call();
}



void insert_declaration_list(string text, string data_type)
{
    string part = "";
    vector<string> items;

    for (int i = 0; i <= (int)text.size(); i++)
    {
        if (i == (int)text.size() || text[i] == ',')
        {
            items.push_back(part);
            part = "";
        }
        else
        {
            part += text[i];
        }
    }

    for (int i = 0; i < (int)items.size(); i++)
    {
        string item = items[i];
        string name = item;
        string size = "";
        string kind = "Variable";

        size_t left_bracket = item.find('[');
        if (left_bracket != string::npos)
        {
            size_t right_bracket = item.find(']', left_bracket);
            name = item.substr(0, left_bracket);
            size = item.substr(left_bracket + 1, right_bracket - left_bracket - 1);
            kind = "Array";
        }

        symbol_info *symbol = new symbol_info(name, "ID");
        symbol->set_id_kind(kind);
        symbol->set_data_type(data_type);
        if (kind == "Array")
            symbol->set_array_size(size);

        if (!table->insert(symbol))
        {
            semantic_error("Multiple declaration of variable " + name);
            delete symbol;
        }
    }
}



void add_parameter(string data_type, string name)
{
    if (name != "")
    {
        for (int i = 0; i < (int)param_list_v.size(); i++)
        {
            if (param_list_v[i].second == name)
            {
                semantic_error("Multiple declaration of variable " + name + " in parameter of " + func_name);
                break;
            }
        }
    }

    param_list_v.push_back(make_pair(data_type, name));
}


void insert_function()
{
    vector<pair<string,string>> actual_params = param_list_v;

    
    if (actual_params.size() == 1 && actual_params[0].first == "void" && actual_params[0].second == "")
        actual_params.clear();

    symbol_info *fsym = new symbol_info(func_name, "ID");
    fsym->set_id_kind("Function");
    fsym->set_data_type(func_ret_type);
    fsym->set_param_count(actual_params.size());

    string details = "";
    vector<string> parameter_types;

    for (int i = 0; i < (int)actual_params.size(); i++)
    {
        if (i > 0)
            details += ", ";

        details += actual_params[i].first;
        parameter_types.push_back(actual_params[i].first);

        if (actual_params[i].second != "")
            details += " " + actual_params[i].second;
    }

    fsym->set_param_details(details);
    fsym->set_param_types(parameter_types);

    if (!table->insert(fsym))
    {
        semantic_error("Multiple declaration of function " + func_name);
        delete fsym;
    }

    table->enter_scope();

    
    
    for (int i = 0; i < (int)actual_params.size(); i++)
    {
        if (actual_params[i].second == "")
            continue;

        symbol_info *psym = new symbol_info(actual_params[i].second, "ID");
        psym->set_id_kind("Variable");
        psym->set_data_type(actual_params[i].first);

        if (!table->insert(psym))
            delete psym;
    }

    param_list_v.clear();
    func_scope = false;
}

void yyerror(const char *s)
{
    semantic_error(s);
}

%}

%token IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN ADDOP MULOP INCOP DECOP RELOP ASSIGNOP LOGICOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON CONST_INT CONST_FLOAT ID

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

start : program
    {
        outlog << "At line no: " << lines << " start : program " << endl << endl;
        outlog << "Symbol Table" << endl << endl;
        table->print_all_scopes(outlog);
    }
    ;

program : program unit
    {
        outlog << "At line no: " << lines << " program : program unit " << endl << endl;
        outlog << $1->get_name() + "\n" + $2->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name() + "\n" + $2->get_name(), "program");
    }
    | unit
    {
        outlog << "At line no: " << lines << " program : unit " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "program");
    }
    ;

unit : variable_decl
    {
        outlog << "At line no: " << lines << " unit : variable_decl " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "unit");
    }
    | func_definition
    {
        outlog << "At line no: " << lines << " unit : func_definition " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "unit");
    }
    ;

func_definition : type_specifier ID LPAREN
    {
        func_ret_type = $1->get_name();
        func_name = $2->get_name();
        param_list_v.clear();
        func_scope = true;
    }
    param_list RPAREN compound_statement
    {
        outlog << "At line no: " << lines << " func_definition : type_specifier ID LPAREN param_list RPAREN compound_statement " << endl << endl;
        outlog << $1->get_name() << " " << $2->get_name() << "(" << $5->get_name() << ")\n" << $7->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name() + " " + $2->get_name() + "(" + $5->get_name() + ")\n" + $7->get_name(), "func_def");
    }
    | type_specifier ID LPAREN
    {
        func_ret_type = $1->get_name();
        func_name = $2->get_name();
        param_list_v.clear();
        func_scope = true;
    }
    RPAREN compound_statement
    {
        outlog << "At line no: " << lines << " func_definition : type_specifier ID LPAREN RPAREN compound_statement " << endl << endl;
        outlog << $1->get_name() << " " << $2->get_name() << "()\n" << $6->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name() + " " + $2->get_name() + "()\n" + $6->get_name(), "func_def");
    }
    ;

param_list : param_list COMMA type_specifier ID
    {
        outlog << "At line no: " << lines << " param_list : param_list COMMA type_specifier ID " << endl << endl;
        outlog << $1->get_name() << "," << $3->get_name() << " " << $4->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name() + "," + $3->get_name() + " " + $4->get_name(), "param_list");
        add_parameter($3->get_name(), $4->get_name());
    }
    | param_list COMMA type_specifier
    {
        outlog << "At line no: " << lines << " param_list : param_list COMMA type_specifier " << endl << endl;
        outlog << $1->get_name() << "," << $3->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name() + "," + $3->get_name(), "param_list");
        add_parameter($3->get_name(), "");
    }
    | type_specifier ID
    {
        outlog << "At line no: " << lines << " param_list : type_specifier ID " << endl << endl;
        outlog << $1->get_name() << " " << $2->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name() + " " + $2->get_name(), "param_list");
        add_parameter($1->get_name(), $2->get_name());
    }
    | type_specifier
    {
        outlog << "At line no: " << lines << " param_list : type_specifier " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "param_list");
        add_parameter($1->get_name(), "");
    }
    ;

compound_statement : LCURL
    {
        if (func_scope)
            insert_function();
        else
            table->enter_scope();
    }
    statements RCURL
    {
        outlog << "At line no: " << lines << " compound_statement : LCURL statements RCURL " << endl << endl;
        outlog << "{\n" + $3->get_name() + "\n}" << endl << endl;
        $$ = new symbol_info("{\n" + $3->get_name() + "\n}", "comp_stmnt");
        table->print_all_scopes(outlog);
        table->exit_scope();
    }
    | LCURL
    {
        if (func_scope)
            insert_function();
        else
            table->enter_scope();
    }
    RCURL
    {
        outlog << "At line no: " << lines << " compound_statement : LCURL RCURL " << endl << endl;
        outlog << "{\n}" << endl << endl;
        $$ = new symbol_info("{\n}", "comp_stmnt");
        table->print_all_scopes(outlog);
        table->exit_scope();
    }
    ;

variable_decl : type_specifier declaration_list SEMICOLON
    {
        outlog << "At line no: " << lines << " variable_decl : type_specifier declaration_list SEMICOLON " << endl << endl;
        outlog << $1->get_name() << " " << $2->get_name() << ";" << endl << endl;
        $$ = new symbol_info($1->get_name() + " " + $2->get_name() + ";", "var_dec");
        insert_declaration_list($2->get_name(), $1->get_name());
    }
    ;

type_specifier : INT
    {
        outlog << "At line no: " << lines << " type_specifier : INT " << endl << endl;
        outlog << "int" << endl << endl;
        $$ = new symbol_info("int", "type");
        var_type = "int";
    }
    | FLOAT
    {
        outlog << "At line no: " << lines << " type_specifier : FLOAT " << endl << endl;
        outlog << "float" << endl << endl;
        $$ = new symbol_info("float", "type");
        var_type = "float";
    }
    | VOID
    {
        outlog << "At line no: " << lines << " type_specifier : VOID " << endl << endl;
        outlog << "void" << endl << endl;
        $$ = new symbol_info("void", "type");
        var_type = "void";
    }
    | CHAR
    {
        outlog << "At line no: " << lines << " type_specifier : CHAR " << endl << endl;
        outlog << "char" << endl << endl;
        $$ = new symbol_info("char", "type");
        var_type = "char";
    }
    | DOUBLE
    {
        outlog << "At line no: " << lines << " type_specifier : DOUBLE " << endl << endl;
        outlog << "double" << endl << endl;
        $$ = new symbol_info("double", "type");
        var_type = "double";
    }
    ;

declaration_list : declaration_list COMMA ID
    {
        outlog << "At line no: " << lines << " declaration_list : declaration_list COMMA ID " << endl << endl;
        outlog << $1->get_name() + "," << $3->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name() + "," + $3->get_name(), "decl_list");
    }
    | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
    {
        outlog << "At line no: " << lines << " declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD " << endl << endl;
        outlog << $1->get_name() + "," << $3->get_name() << "[" << $5->get_name() << "]" << endl << endl;
        $$ = new symbol_info($1->get_name() + "," + $3->get_name() + "[" + $5->get_name() + "]", "decl_list");
    }
    | ID
    {
        outlog << "At line no: " << lines << " declaration_list : ID " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "decl_list");
    }
    | ID LTHIRD CONST_INT RTHIRD
    {
        outlog << "At line no: " << lines << " declaration_list : ID LTHIRD CONST_INT RTHIRD " << endl << endl;
        outlog << $1->get_name() << "[" << $3->get_name() << "]" << endl << endl;
        $$ = new symbol_info($1->get_name() + "[" + $3->get_name() + "]", "decl_list");
    }
    ;

statements : statement
    {
        outlog << "At line no: " << lines << " statements : statement " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "stmnts");
    }
    | statements statement
    {
        outlog << "At line no: " << lines << " statements : statements statement " << endl << endl;
        outlog << $1->get_name() << "\n" << $2->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name() + "\n" + $2->get_name(), "stmnts");
    }
    ;

statement : variable_decl
    {
        outlog << "At line no: " << lines << " statement : variable_decl " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "stmnt");
    }
    | func_definition
    {
        outlog << "At line no: " << lines << " statement : func_definition " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "stmnt");
    }
    | expression_statement
    {
        outlog << "At line no: " << lines << " statement : expression_statement " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "stmnt");
    }
    | compound_statement
    {
        outlog << "At line no: " << lines << " statement : compound_statement " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "stmnt");
    }
    | FOR LPAREN expression_statement expression_statement expression RPAREN statement
    {
        outlog << "At line no: " << lines << " statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement " << endl << endl;
        outlog << "for(" << $3->get_name() << $4->get_name() << $5->get_name() << ")\n" << $7->get_name() << endl << endl;
        if (contains_void_function($5))
            semantic_error("Void function cannot be used as part of an expression");
        $$ = new symbol_info("for(" + $3->get_name() + $4->get_name() + $5->get_name() + ")\n" + $7->get_name(), "stmnt");
    }
    | IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
    {
        outlog << "At line no: " << lines << " statement : IF LPAREN expression RPAREN statement " << endl << endl;
        outlog << "if(" << $3->get_name() << ")\n" << $5->get_name() << endl << endl;
        if (contains_void_function($3))
            semantic_error("Void function cannot be used as part of an expression");
        $$ = new symbol_info("if(" + $3->get_name() + ")\n" + $5->get_name(), "stmnt");
    }
    | IF LPAREN expression RPAREN statement ELSE statement
    {
        outlog << "At line no: " << lines << " statement : IF LPAREN expression RPAREN statement ELSE statement " << endl << endl;
        outlog << "if(" << $3->get_name() << ")\n" << $5->get_name() << "\nelse\n" << $7->get_name() << endl << endl;
        if (contains_void_function($3))
            semantic_error("Void function cannot be used as part of an expression");
        $$ = new symbol_info("if(" + $3->get_name() + ")\n" + $5->get_name() + "\nelse\n" + $7->get_name(), "stmnt");
    }
    | WHILE LPAREN expression RPAREN statement
    {
        outlog << "At line no: " << lines << " statement : WHILE LPAREN expression RPAREN statement " << endl << endl;
        outlog << "while(" << $3->get_name() << ")\n" << $5->get_name() << endl << endl;
        if (contains_void_function($3))
            semantic_error("Void function cannot be used as part of an expression");
        $$ = new symbol_info("while(" + $3->get_name() + ")\n" + $5->get_name(), "stmnt");
    }
    | PRINTLN LPAREN ID RPAREN SEMICOLON
    {
        outlog << "At line no: " << lines << " statement : PRINTLN LPAREN ID RPAREN SEMICOLON " << endl << endl;
        outlog << "printf(" << $3->get_name() << ");" << endl << endl;
        symbol_info *found = table->lookup($3);
        if (found == NULL)
            semantic_error("Undeclared variable " + $3->get_name());
        else if (found->get_id_kind() == "Array")
            semantic_error("Array used without index: " + $3->get_name());
        else if (found->get_id_kind() == "Function")
            semantic_error("Function identifier used as a variable: " + $3->get_name());
        $$ = new symbol_info("printf(" + $3->get_name() + ");", "stmnt");
    }
    | RETURN expression SEMICOLON
    {
        outlog << "At line no: " << lines << " statement : RETURN expression SEMICOLON " << endl << endl;
        outlog << "return " << $2->get_name() << ";" << endl << endl;
        if (contains_void_function($2))
            semantic_error("Void function cannot be used as part of an expression");
        $$ = new symbol_info("return " + $2->get_name() + ";", "stmnt");
    }
    ;

expression_statement : SEMICOLON
    {
        outlog << "At line no: " << lines << " expression_statement : SEMICOLON " << endl << endl;
        outlog << ";" << endl << endl;
        $$ = new symbol_info(";", "expr_stmt");
    }
    | expression SEMICOLON
    {
        outlog << "At line no: " << lines << " expression_statement : expression SEMICOLON " << endl << endl;
        outlog << $1->get_name() << ";" << endl << endl;
        $$ = new symbol_info($1->get_name() + ";", "expr_stmt");
        copy_type($$, $1);
    }
    ;

variable : ID
    {
        outlog << "At line no: " << lines << " variable : ID " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "varbl");

        symbol_info *found = table->lookup($1);

        if (found == NULL)
        {
            semantic_error("Undeclared variable " + $1->get_name());
            $$->set_data_type("error");
        }
        else if (found->get_id_kind() == "Array")
        {
            
            semantic_error("Array used without index: " + $1->get_name());
            $$->set_data_type("error");
        }
        else if (found->get_id_kind() == "Function")
        {
            semantic_error("Function identifier used as a variable: " + $1->get_name());
            $$->set_data_type("error");
        }
        else
        {
            $$->set_data_type(found->get_data_type());
        }
    }
    | ID LTHIRD expression RTHIRD
    {
        outlog << "At line no: " << lines << " variable : ID LTHIRD expression RTHIRD " << endl << endl;
        outlog << $1->get_name() << "[" << $3->get_name() << "]" << endl << endl;
        $$ = new symbol_info($1->get_name() + "[" + $3->get_name() + "]", "varbl");

        symbol_info *found = table->lookup($1);

        if (found == NULL)
        {
            semantic_error("Undeclared variable " + $1->get_name());
            $$->set_data_type("error");
        }
        else if (found->get_id_kind() != "Array")
        {
            semantic_error("Index used with a non-array variable: " + $1->get_name());
            $$->set_data_type("error");
        }
        else if (contains_void_function($3))
        {
            semantic_error("Void function cannot be used as part of an expression");
            $$->set_data_type("error");
        }
        else if ($3->get_data_type() == "error")
        {
            
            
            $$->set_data_type("error");
        }
        else if ($3->get_data_type() != "int")
        {
            semantic_error("Array index is not an integer: " + $1->get_name());
            $$->set_data_type("error");
        }
        else
        {
            $$->set_data_type(found->get_data_type());
        }
    }
    ;

expression : logic_expression
    {
        outlog << "At line no: " << lines << " expression : logic_expression " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "expr");
        copy_type($$, $1);
    }
    | variable ASSIGNOP logic_expression
    {
        outlog << "At line no: " << lines << " expression : variable ASSIGNOP logic_expression " << endl << endl;
        outlog << $1->get_name() << "=" << $3->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name() + "=" + $3->get_name(), "expr");

        string left_type = $1->get_data_type();
        string right_type = $3->get_data_type();

        if (left_type == "error" || right_type == "error")
        {
            $$->set_data_type("error");
        }
        else if (contains_void_function($3))
        {
            semantic_error("Void function cannot be used as part of an expression");
            $$->set_data_type("error");
        }
        else if (left_type == right_type)
        {
            $$->set_data_type(left_type);
        }
        else if (is_numeric_type(left_type) && is_numeric_type(right_type))
        {
            
            if (type_rank(left_type) < type_rank(right_type))
            {
                semantic_error("Type mismatch in assignment: cannot assign " + right_type + " to " + left_type + " without data loss");
            }
            $$->set_data_type(left_type);
        }
        else
        {
            semantic_error("Type mismatch in assignment: " + left_type + " = " + right_type);
            $$->set_data_type("error");
        }
    }
    ;

logic_expression : rel_expression
    {
        outlog << "At line no: " << lines << " logic_expression : rel_expression " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "lgc_expr");
        copy_type($$, $1);
    }
    | rel_expression LOGICOP rel_expression
    {
        outlog << "At line no: " << lines << " logic_expression : rel_expression LOGICOP rel_expression " << endl << endl;
        outlog << $1->get_name() << $2->get_name() << $3->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name() + $2->get_name() + $3->get_name(), "lgc_expr");

        if ($1->get_data_type() == "error" || $3->get_data_type() == "error")
        {
            $$->set_data_type("error");
        }
        else if (contains_void_function($1) || contains_void_function($3))
        {
            semantic_error("Void function cannot be used as part of an expression");
            $$->set_data_type("error");
        }
        else
        {
            
            $$->set_data_type("int");
            set_binary_constant($$, $1, $2->get_name(), $3);
        }
    }
    ;

rel_expression : simple_expression
    {
        outlog << "At line no: " << lines << " rel_expression : simple_expression " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "rel_expr");
        copy_type($$, $1);
    }
    | simple_expression RELOP simple_expression
    {
        outlog << "At line no: " << lines << " rel_expression : simple_expression RELOP simple_expression " << endl << endl;
        outlog << $1->get_name() << $2->get_name() << $3->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name() + $2->get_name() + $3->get_name(), "rel_expr");

        if ($1->get_data_type() == "error" || $3->get_data_type() == "error")
        {
            $$->set_data_type("error");
        }
        else if (contains_void_function($1) || contains_void_function($3))
        {
            semantic_error("Void function cannot be used as part of an expression");
            $$->set_data_type("error");
        }
        else
        {
            
            $$->set_data_type("int");
            set_binary_constant($$, $1, $2->get_name(), $3);
        }
    }
    ;

simple_expression : term
    {
        outlog << "At line no: " << lines << " simple_expression : term " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "simp_expr");
        copy_type($$, $1);
    }
    | simple_expression ADDOP term
    {
        outlog << "At line no: " << lines << " simple_expression : simple_expression ADDOP term " << endl << endl;
        outlog << $1->get_name() << $2->get_name() << $3->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name() + $2->get_name() + $3->get_name(), "simp_expr");

        if ($1->get_data_type() == "error" || $3->get_data_type() == "error")
        {
            $$->set_data_type("error");
        }
        else if (contains_void_function($1) || contains_void_function($3))
        {
            semantic_error("Void function cannot be used as part of an expression");
            $$->set_data_type("error");
        }
        else
        {
            string result_type = arithmetic_type($1->get_data_type(), $3->get_data_type());
            if (result_type == "error")
                semantic_error("Invalid operand types for arithmetic operator " + $2->get_name());

            $$->set_data_type(result_type);
            if (result_type != "error")
                set_binary_constant($$, $1, $2->get_name(), $3);
        }
    }
    ;

term : unary_expression
    {
        outlog << "At line no: " << lines << " term : unary_expression " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "term");
        copy_type($$, $1);
    }
    | term MULOP unary_expression
    {
        outlog << "At line no: " << lines << " term : term MULOP unary_expression " << endl << endl;
        outlog << $1->get_name() << $2->get_name() << $3->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name() + $2->get_name() + $3->get_name(), "term");

        string op = $2->get_name();
        string left_type = $1->get_data_type();
        string right_type = $3->get_data_type();

        if (left_type == "error" || right_type == "error")
        {
            $$->set_data_type("error");
        }
        else if (contains_void_function($1) || contains_void_function($3))
        {
            semantic_error("Void function cannot be used as part of an expression");
            $$->set_data_type("error");
        }
        else if (op == "%")
        {
            
            if (left_type != "int" || right_type != "int")
            {
                semantic_error("Operands of modulus operator must be integers");
                $$->set_data_type("error");
            }
            else if (is_zero($3))
            {
                semantic_error("Modulus by zero");
                $$->set_data_type("error");
            }
            else
            {
                $$->set_data_type("int");
                set_binary_constant($$, $1, op, $3);
            }
        }
        else if (op == "/")
        {
            
            if (is_zero($3))
            {
                semantic_error("Division by zero");
                $$->set_data_type("error");
            }
            else
            {
                string result_type = arithmetic_type(left_type, right_type);
                if (result_type == "error")
                    semantic_error("Invalid operand types for division");

                $$->set_data_type(result_type);
                if (result_type != "error")
                    set_binary_constant($$, $1, op, $3);
            }
        }
        else
        {
            string result_type = arithmetic_type(left_type, right_type);
            if (result_type == "error")
                semantic_error("Invalid operand types for multiplication");

            $$->set_data_type(result_type);
            if (result_type != "error")
                set_binary_constant($$, $1, op, $3);
        }
    }
    ;

unary_expression : ADDOP unary_expression
    {
        outlog << "At line no: " << lines << " unary_expression : ADDOP unary_expression " << endl << endl;
        outlog << $1->get_name() << $2->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name() + $2->get_name(), "un_expr");

        if ($2->get_data_type() == "error")
        {
            $$->set_data_type("error");
        }
        else if (contains_void_function($2))
        {
            semantic_error("Void function cannot be used as part of an expression");
            $$->set_data_type("error");
        }
        else
        {
            copy_type($$, $2);
            $$->set_void_function_call(false);
            if ($2->has_constant_value() && $1->get_name() == "-")
                $$->set_constant_value(-$2->get_constant_value());
        }
    }
    | NOT unary_expression
    {
        outlog << "At line no: " << lines << " unary_expression : NOT unary_expression " << endl << endl;
        outlog << "!" << $2->get_name() << endl << endl;
        $$ = new symbol_info("!" + $2->get_name(), "un_expr");

        if ($2->get_data_type() == "error")
        {
            $$->set_data_type("error");
        }
        else if (contains_void_function($2))
        {
            semantic_error("Void function cannot be used as part of an expression");
            $$->set_data_type("error");
        }
        else
        {
            $$->set_data_type("int");
            if ($2->has_constant_value())
                $$->set_constant_value($2->get_constant_value() == 0);
        }
    }
    | factor_info
    {
        outlog << "At line no: " << lines << " unary_expression : factor_info " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "un_expr");
        copy_type($$, $1);
    }
    ;

factor_info : factor
    {
        outlog << "At line no: " << lines << " factor_info : factor " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "fctr_info");
        copy_type($$, $1);
    }
    ;

factor : variable
    {
        outlog << "At line no: " << lines << " factor : variable " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "fctr");
        copy_type($$, $1);
    }
    | ID LPAREN argument_list RPAREN
    {
        outlog << "At line no: " << lines << " factor : ID LPAREN argument_list RPAREN " << endl << endl;
        outlog << $1->get_name() << "(" << $3->get_name() << ")" << endl << endl;
        $$ = new symbol_info($1->get_name() + "(" + $3->get_name() + ")", "fctr");

        symbol_info *found = table->lookup($1);

        if (found == NULL)
        {
            semantic_error("Undeclared function: " + $1->get_name());
            $$->set_data_type("error");
        }
        else if (found->get_id_kind() != "Function")
        {
            semantic_error("Function call made with a non-function identifier: " + $1->get_name());
            $$->set_data_type("error");
        }
        else
        {
            vector<string> expected_types = found->get_param_types();
            vector<string> given_types = $3->get_argument_types();
            bool call_error = false;

            if (given_types.size() != expected_types.size())
            {
                semantic_error("Incorrect number of arguments in function call: " + $1->get_name());
                call_error = true;
            }
            else
            {
                for (int i = 0; i < (int)given_types.size(); i++)
                {
                    
                    
                    if (given_types[i] == "error")
                    {
                        call_error = true;
                        continue;
                    }

                    if (given_types[i] != expected_types[i])
                    {
                        semantic_error("Argument " + to_string(i + 1) + " type mismatch in function call: " + $1->get_name());
                        call_error = true;
                    }
                }
            }

            if (call_error)
            {
                $$->set_data_type("error");
            }
            else
            {
                $$->set_data_type(found->get_data_type());
                if (found->get_data_type() == "void")
                    $$->set_void_function_call(true);
            }
        }
    }
    | LPAREN expression RPAREN
    {
        outlog << "At line no: " << lines << " factor : LPAREN expression RPAREN " << endl << endl;
        outlog << "(" << $2->get_name() << ")" << endl << endl;
        $$ = new symbol_info("(" + $2->get_name() + ")", "fctr");
        copy_type($$, $2);
    }
    | CONST_INT
    {
        outlog << "At line no: " << lines << " factor : CONST_INT " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "fctr");
        $$->set_data_type("int");
        $$->set_constant_value(atof($1->get_name().c_str()));
    }
    | CONST_FLOAT
    {
        outlog << "At line no: " << lines << " factor : CONST_FLOAT " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "fctr");
        $$->set_data_type("float");
        $$->set_constant_value(atof($1->get_name().c_str()));
    }
    | variable INCOP
    {
        outlog << "At line no: " << lines << " factor : variable INCOP " << endl << endl;
        outlog << $1->get_name() << "++" << endl << endl;
        $$ = new symbol_info($1->get_name() + "++", "fctr");
        copy_type($$, $1);
    }
    | variable DECOP
    {
        outlog << "At line no: " << lines << " factor : variable DECOP " << endl << endl;
        outlog << $1->get_name() << "--" << endl << endl;
        $$ = new symbol_info($1->get_name() + "--", "fctr");
        copy_type($$, $1);
    }
    ;

argument_list : arguments
    {
        outlog << "At line no: " << lines << " argument_list : arguments " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "arg_list");
        $$->set_argument_types($1->get_argument_types());
    }
    |
    {
        outlog << "At line no: " << lines << " argument_list :  " << endl << endl;
        outlog << "" << endl << endl;
        $$ = new symbol_info("", "arg_list");
        vector<string> types;
        $$->set_argument_types(types);
    }
    ;

arguments : arguments COMMA logic_expression
    {
        outlog << "At line no: " << lines << " arguments : arguments COMMA logic_expression " << endl << endl;
        outlog << $1->get_name() << "," << $3->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name() + "," + $3->get_name(), "arg");

        vector<string> types = $1->get_argument_types();

        if (contains_void_function($3))
        {
            semantic_error("Void function cannot be used as part of an expression");
            types.push_back("error");
        }
        else
        {
            types.push_back($3->get_data_type());
        }
        $$->set_argument_types(types);
    }
    | logic_expression
    {
        outlog << "At line no: " << lines << " arguments : logic_expression " << endl << endl;
        outlog << $1->get_name() << endl << endl;
        $$ = new symbol_info($1->get_name(), "arg");

        vector<string> types;
        if (contains_void_function($1))
        {
            semantic_error("Void function cannot be used as part of an expression");
            types.push_back("error");
        }
        else
        {
            types.push_back($1->get_data_type());
        }
        $$->set_argument_types(types);
    }
    ;

%%

int main(int argc, char *argv[])
{
    if (argc != 2)
    {
        cout << "Please input file name" << endl;
        return 0;
    }

    yyin = fopen(argv[1], "r");
    outlog.open("24241172_24241333_log.txt", ios::trunc);
    outerror.open("24241172_24241333_error.txt", ios::trunc);

    if (yyin == NULL)
    {
        cout << "Couldn't open file" << endl;
        return 0;
    }

    table = new symbol_table(10);
    table->enter_scope();

    yyparse();

    outlog << endl << "Total lines: " << lines << endl;
    outlog << "Total errors: " << error_count << endl;

    outerror << "Total errors: " << error_count << endl;

    outlog.close();
    outerror.close();
    fclose(yyin);

    delete table;
    return 0;
}
