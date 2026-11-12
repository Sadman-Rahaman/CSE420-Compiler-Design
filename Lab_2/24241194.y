%{

#include <fstream>
extern std::ofstream outlog;
#include "symbol_table.h"

#define YYSTYPE symbol_info*

extern FILE *yyin;
int yyparse(void);
int yylex(void);
extern YYSTYPE yylval;

symbol_table *symtable = nullptr;
vector<pair<string, string>> pending_parameters;
bool insert_pending_parameters = false;

int lines = 1;
ofstream outlog;


void add_symbol(symbol_info * symbol)
{
	if (!symtable->insert(symbol))
	{
		delete symbol;
	}
}



string get_node_type(symbol_info *node)
{
	if (node == nullptr)
	{
		return "";
	}
	if (node->get_expression_type() != "")
	{
		return node->get_expression_type();
	}
	return node->get_data_type();
}


symbol_info *lookup_symbol_by_name(const string &name)
{
	if (symtable == nullptr)
	{
		return nullptr;
	}
	symbol_info temp(name, "ID");
	return symtable->lookup(&temp);
}


void report_function_call_mismatches(symbol_info *function_symbol, symbol_info *argument_list)
{
	if (function_symbol == nullptr || argument_list == nullptr)
	{
		return;
	}

	vector<string> actual_types = argument_list->get_parameter_types();
	vector<string> formal_types = function_symbol->get_parameter_types();
	int total_arguments = max((int)actual_types.size(), (int)formal_types.size());

	for (int i = 0; i < total_arguments; i++)
	{
		string actual_type = i < (int)actual_types.size() ? actual_types[i] : "";
		string formal_type = i < (int)formal_types.size() ? formal_types[i] : "";
		if (actual_type != formal_type)
		{
			outlog << "At line no: " << lines << " argument " << (i + 1)
			       << " type mismatch in function call: " << function_symbol->get_name() << endl
			       << endl;
		}
	}
}

void yyerror(char *s)
{
	outlog<<"At line "<<lines<<" "<<s<<endl<<endl;
}

%}

%token IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN ADDOP MULOP INCOP DECOP RELOP ASSIGNOP LOGICOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON CONST_INT CONST_FLOAT ID

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE
%%

start : program
		{
			outlog<<"At line no: "<<lines<<" start : program "<<endl<<endl;
			outlog<<"Symbol Table"<<endl<<endl;
			symtable->print_all_scopes(outlog);
		}
		;

program : program unit
		{
			outlog<<"At line no: "<<lines<<" program : program unit "<<endl<<endl;
			outlog<<$1->getname()+"\n"+$2->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+"\n"+$2->getname(),"program");
		}
		| unit
		{
			outlog<<"At line no: "<<lines<<" program : unit "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"program");
		}
		;

unit : variable_decl
	   {
		  	outlog<<"At line no: "<<lines<<" unit : variable_decl "<<endl<<endl;
		  	outlog<<$1->getname()<<endl<<endl;
		
		  	$$ = new symbol_info($1->getname(),"unit");
	    }
        | func_definition
        {
		  	outlog<<"At line no: "<<lines<<" unit : func_definition "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
		
			$$ = new symbol_info($1->getname(),"unit");
		}
     	;

func_definition : type_specifier ID LPAREN param_list RPAREN
		{
			symbol_info *func_sym = new symbol_info($2->getname(), "ID");
			func_sym->set_symbol_kind("function_definition");
			func_sym->set_data_type($1->getname());

			vector<string> ptypes = $4->get_parameter_types();
			vector<string> pnames = $4->get_parameter_names();
			for (int p = 0; p < (int)ptypes.size(); p++)
			{
				func_sym->add_parameter(ptypes[p], pnames[p]);
			}
			add_symbol(func_sym);

			pending_parameters.clear();
			for (int p = 0; p < (int)ptypes.size(); p++)
			{
				pending_parameters.push_back({ptypes[p], pnames[p]});
			}
			insert_pending_parameters = true;
		}
		compound_statement
		{	
			outlog<<"At line no: "<<lines<<" func_definition : type_specifier ID LPAREN param_list RPAREN compound_statement "<<endl<<endl;
			outlog<<$1->getname()<<" "<<$2->getname()<<"("+$4->getname()+")\n"<<$7->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+" "+$2->getname()+"("+$4->getname()+")\n"+$7->getname(),"func_def");	
		}
		| type_specifier ID LPAREN RPAREN
		{
			symbol_info *func_sym = new symbol_info($2->getname(), "ID");
			func_sym->set_symbol_kind("function_definition");
			func_sym->set_data_type($1->getname());
			add_symbol(func_sym);

			pending_parameters.clear();
			insert_pending_parameters = true;
		}
		compound_statement
		{
			outlog<<"At line no: "<<lines<<" func_definition : type_specifier ID LPAREN RPAREN compound_statement "<<endl<<endl;
			outlog<<$1->getname()<<" "<<$2->getname()<<"()\n"<<$6->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+" "+$2->getname()+"()\n"+$6->getname(),"func_def");	
		}
 		;

param_list : param_list COMMA type_specifier ID
		{
			outlog<<"At line no: "<<lines<<" param_list : param_list COMMA type_specifier ID "<<endl<<endl;
			outlog<<$1->getname()<<","<<$3->getname()<<" "<<$4->getname()<<endl<<endl;
					
			$$ = new symbol_info($1->getname()+","+$3->getname()+" "+$4->getname(),"param_list");
			vector<string> ptypes = $1->get_parameter_types();
			vector<string> pnames = $1->get_parameter_names();
			for (int p = 0; p < (int)ptypes.size(); p++)
			{
				$$->add_parameter(ptypes[p], pnames[p]);
			}
			$$->add_parameter($3->getname(), $4->getname());
		}
		| param_list COMMA type_specifier
		{
			outlog<<"At line no: "<<lines<<" param_list : param_list COMMA type_specifier "<<endl<<endl;
			outlog<<$1->getname()<<","<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+","+$3->getname(),"param_list");
			vector<string> ptypes = $1->get_parameter_types();
			vector<string> pnames = $1->get_parameter_names();
			for (int p = 0; p < (int)ptypes.size(); p++)
			{
				$$->add_parameter(ptypes[p], pnames[p]);
			}
			$$->add_parameter($3->getname());
		}
 		| type_specifier ID
 		{
			outlog<<"At line no: "<<lines<<" param_list : type_specifier ID "<<endl<<endl;
			outlog<<$1->getname()<<" "<<$2->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+" "+$2->getname(),"param_list");
			$$->add_parameter($1->getname(), $2->getname());
		}
		| type_specifier
		{
			outlog<<"At line no: "<<lines<<" param_list : type_specifier "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"param_list");
			$$->add_parameter($1->getname());
		}
 		;

compound_statement : LCURL
		{
			symtable->enter_scope();
			if (insert_pending_parameters)
			{
				for (auto &param : pending_parameters)
				{
					if (param.second == "")
					{
						continue;
					}
					symbol_info *param_sym = new symbol_info(param.second, "ID");
					param_sym->set_symbol_kind("variable");
					param_sym->set_data_type(param.first);
					add_symbol(param_sym);
				}
				pending_parameters.clear();
				insert_pending_parameters = false;
			}
		}
		statements RCURL
		{ 
 		    outlog<<"At line no: "<<lines<<" compound_statement : LCURL statements RCURL "<<endl<<endl;
			outlog<<"{\n"+$3->getname()+"\n}"<<endl<<endl;
				
			$$ = new symbol_info("{\n"+$3->getname()+"\n}","comp_stmnt");
			symtable->print_all_scopes(outlog);
			symtable->exit_scope();
 		}
 		| LCURL
		{
			symtable->enter_scope();
			if (insert_pending_parameters)
			{
				for (auto &param : pending_parameters)
				{
					if (param.second == "")
					{
						continue;
					}
					symbol_info *param_sym = new symbol_info(param.second, "ID");
					param_sym->set_symbol_kind("variable");
					param_sym->set_data_type(param.first);
					add_symbol(param_sym);
				}
				pending_parameters.clear();
				insert_pending_parameters = false;
			}
		}
		RCURL
 		{ 
 		    outlog<<"At line no: "<<lines<<" compound_statement : LCURL RCURL "<<endl<<endl;
			outlog<<"{\n}"<<endl<<endl;
				
			$$ = new symbol_info("{\n}","comp_stmnt");
			symtable->print_all_scopes(outlog);
			symtable->exit_scope();
 		}
 		;
 		    
variable_decl : type_specifier declaration_list SEMICOLON
	 	{
			outlog<<"At line no: "<<lines<<" variable_decl : type_specifier declaration_list SEMICOLON "<<endl<<endl;
			outlog<<$1->getname()<<" "<<$2->getname()<<";"<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+" "+$2->getname()+";","var_dec");

			vector<string> names = $2->get_declaration_names();
			vector<int> sizes = $2->get_declaration_sizes();
			for (int i = 0; i < (int)names.size(); i++)
			{
				symbol_info *var_sym = new symbol_info(names[i], "ID");
				var_sym->set_data_type($1->getname());
				if (sizes[i] != -1)
				{
					var_sym->set_symbol_kind("array");
					var_sym->set_array_size(sizes[i]);
				}
				else
				{
					var_sym->set_symbol_kind("variable");
				}
				add_symbol(var_sym);
			}
		}
		;

type_specifier : INT
		{
			outlog<<"At line no: "<<lines<<" type_specifier : INT "<<endl<<endl;
			outlog<<"int"<<endl<<endl;
			
			$$ = new symbol_info("int","type");
	    }
 		| FLOAT
 		{
			outlog<<"At line no: "<<lines<<" type_specifier : FLOAT "<<endl<<endl;
			outlog<<"float"<<endl<<endl;
			
			$$ = new symbol_info("float","type");
	    }
 		| VOID
 		{
			outlog<<"At line no: "<<lines<<" type_specifier : VOID "<<endl<<endl;
			outlog<<"void"<<endl<<endl;
			
			$$ = new symbol_info("void","type");
	    }
		| CHAR
 		{
			outlog<<"At line no: "<<lines<<" type_specifier : CHAR "<<endl<<endl;
			outlog<<"char"<<endl<<endl;
			
			$$ = new symbol_info("char","type");
	    }
 		;

declaration_list : declaration_list COMMA ID
		{
 		  	outlog<<"At line no: "<<lines<<" declaration_list : declaration_list COMMA ID "<<endl<<endl;
 		  	outlog<<$1->getname()+","<<$3->getname()<<endl<<endl;

			$$ = new symbol_info($1->getname()+","+$3->getname(),"decl_list");
			vector<string> names = $1->get_declaration_names();
			vector<int> sizes = $1->get_declaration_sizes();
			for (int i = 0; i < (int)names.size(); i++)
			{
				$$->add_declaration(names[i], sizes[i]);
			}
			$$->add_declaration($3->getname());
 		}
 		| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD 
 		{
 		  	outlog<<"At line no: "<<lines<<" declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD "<<endl<<endl;
 		  	outlog<<$1->getname()+","<<$3->getname()<<"["<<$5->getname()<<"]"<<endl<<endl;

			$$ = new symbol_info($1->getname()+","+$3->getname()+"["+$5->getname()+"]","decl_list");
			vector<string> names = $1->get_declaration_names();
			vector<int> sizes = $1->get_declaration_sizes();
			for (int i = 0; i < (int)names.size(); i++)
			{
				$$->add_declaration(names[i], sizes[i]);
			}
			$$->add_declaration($3->getname(), atoi($5->getname().c_str()));
 		}
 		|ID
 		{
 		  	outlog<<"At line no: "<<lines<<" declaration_list : ID "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;

			$$ = new symbol_info($1->getname(),"decl_list");
			$$->add_declaration($1->getname());
 		}
 		| ID LTHIRD CONST_INT RTHIRD //array
 		{
 		  	outlog<<"At line no: "<<lines<<" declaration_list : ID LTHIRD CONST_INT RTHIRD "<<endl<<endl;
			outlog<<$1->getname()<<"["<<$3->getname()<<"]"<<endl<<endl;

			$$ = new symbol_info($1->getname()+"["+$3->getname()+"]","decl_list");
			$$->add_declaration($1->getname(), atoi($3->getname().c_str()));
 		}
 		;
 		  

statements : statement
	   {
	    	outlog<<"At line no: "<<lines<<" statements : statement "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"stmnts");
	   }
	   | statements statement
	   {
	    	outlog<<"At line no: "<<lines<<" statements : statements statement "<<endl<<endl;
			outlog<<$1->getname()<<"\n"<<$2->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+"\n"+$2->getname(),"stmnts");
	   }
	   ;
	   
statement : variable_decl
		{
				outlog<<"At line no: "<<lines<<" statement : variable_decl "<<endl<<endl;
				outlog<<$1->getname()<<endl<<endl;
						
				$$ = new symbol_info($1->getname(),"stmnt");
		}
		| func_definition
		{
				outlog<<"At line no: "<<lines<<" statement : func_definition "<<endl<<endl;
				outlog<<$1->getname()<<endl<<endl;

				$$ = new symbol_info($1->getname(),"stmnt");
		}
		| expression_statement
		{
				outlog<<"At line no: "<<lines<<" statement : expression_statement "<<endl<<endl;
				outlog<<$1->getname()<<endl<<endl;
						
				$$ = new symbol_info($1->getname(),"stmnt");
		}
		| compound_statement
		{
				outlog<<"At line no: "<<lines<<" statement : compound_statement "<<endl<<endl;
				outlog<<$1->getname()<<endl<<endl;
						
				$$ = new symbol_info($1->getname(),"stmnt");
		}
		| FOR LPAREN expression_statement expression_statement expression RPAREN statement
		{
				outlog<<"At line no: "<<lines<<" statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement "<<endl<<endl;
				outlog<<"for("<<$3->getname()<<$4->getname()<<$5->getname()<<")\n"<<$7->getname()<<endl<<endl;
						
				$$ = new symbol_info("for("+$3->getname()+$4->getname()+$5->getname()+")\n"+$7->getname(),"stmnt");
		}
		| IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
		{
				outlog<<"At line no: "<<lines<<" statement : IF LPAREN expression RPAREN statement "<<endl<<endl;
				outlog<<"if("<<$3->getname()<<")\n"<<$5->getname()<<endl<<endl;
						
				$$ = new symbol_info("if("+$3->getname()+")\n"+$5->getname(),"stmnt");
		}
		| IF LPAREN expression RPAREN statement ELSE statement
		{
				outlog<<"At line no: "<<lines<<" statement : IF LPAREN expression RPAREN statement ELSE statement "<<endl<<endl;
				outlog<<"if("<<$3->getname()<<")\n"<<$5->getname()<<"\nelse\n"<<$7->getname()<<endl<<endl;
						
				$$ = new symbol_info("if("+$3->getname()+")\n"+$5->getname()+"\nelse\n"+$7->getname(),"stmnt");
		}
	    | WHILE LPAREN expression RPAREN statement
		{
				outlog<<"At line no: "<<lines<<" statement : WHILE LPAREN expression RPAREN statement "<<endl<<endl;
				outlog<<"while("<<$3->getname()<<")\n"<<$5->getname()<<endl<<endl;
						
				$$ = new symbol_info("while("+$3->getname()+")\n"+$5->getname(),"stmnt");
		}
		| PRINTLN LPAREN ID RPAREN SEMICOLON
		{
				outlog<<"At line no: "<<lines<<" statement : PRINTLN LPAREN ID RPAREN SEMICOLON "<<endl<<endl;
				outlog<<"printf("<<$3->getname()<<");"<<endl<<endl; 
						
				$$ = new symbol_info("printf("+$3->getname()+");","stmnt");
		}
		| RETURN expression SEMICOLON
		{
				outlog<<"At line no: "<<lines<<" statement : RETURN expression SEMICOLON "<<endl<<endl;
				outlog<<"return "<<$2->getname()<<";"<<endl<<endl;
						
				$$ = new symbol_info("return "+$2->getname()+";","stmnt");
		}
		;
  
expression_statement : SEMICOLON
		{
			outlog<<"At line no: "<<lines<<" expression_statement : SEMICOLON "<<endl<<endl;
			outlog<<";"<<endl<<endl;
				
			$$ = new symbol_info(";","expr_stmt");
	    } 			
		| expression SEMICOLON 
		{
			outlog<<"At line no: "<<lines<<" expression_statement : expression SEMICOLON "<<endl<<endl;
			outlog<<$1->getname()<<";"<<endl<<endl;
				
			$$ = new symbol_info($1->getname()+";","expr_stmt");
	    }
		;
  
variable : ID 	
       {
			outlog<<"At line no: "<<lines<<" variable : ID "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
				
			$$ = new symbol_info($1->getname(),"varbl");
			symbol_info * resolved = lookup_symbol_by_name($1->getname());
			if (resolved != nullptr)
			{
				$$->set_data_type(resolved->get_data_type());
				$$->set_expression_type(resolved->get_data_type());
			}
	 	} 	
	 	| ID LTHIRD expression RTHIRD 
		{
			outlog<<"At line no: "<<lines<<" variable : ID LTHIRD expression RTHIRD "<<endl<<endl;
			outlog<<$1->getname()<<"["<<$3->getname()<<"]"<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+"["+$3->getname()+"]","varbl");
			symbol_info * resolved = lookup_symbol_by_name($1->getname());
			if (resolved != nullptr)
			{
				$$->set_data_type(resolved->get_data_type());
				$$->set_expression_type(resolved->get_data_type());
			}
		}
	 	;
	 
expression : logic_expression
	   {
	    	outlog<<"At line no: "<<lines<<" expression : logic_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"expr");
			$$->set_expression_type(get_node_type($1));
	   }
	   | variable ASSIGNOP logic_expression 	
	   {
	    	outlog<<"At line no: "<<lines<<" expression : variable ASSIGNOP logic_expression "<<endl<<endl;
			outlog<<$1->getname()<<"="<<$3->getname()<<endl<<endl;

			$$ = new symbol_info($1->getname()+"="+$3->getname(),"expr");
			$$->set_expression_type(get_node_type($1));
	   }
	   ;
			
logic_expression : rel_expression
	    {
	    	outlog<<"At line no: "<<lines<<" logic_expression : rel_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"lgc_expr");
			$$->set_expression_type(get_node_type($1));
	    } 	
		| rel_expression LOGICOP rel_expression 
		{
	    	outlog<<"At line no: "<<lines<<" logic_expression : rel_expression LOGICOP rel_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"lgc_expr");
			$$->set_expression_type("int");
		} 	
		;
			
rel_expression	: simple_expression
		{
	    	outlog<<"At line no: "<<lines<<" rel_expression : simple_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"rel_expr");
			$$->set_expression_type(get_node_type($1));
	    }
		| simple_expression RELOP simple_expression
		{
	    	outlog<<"At line no: "<<lines<<" rel_expression : simple_expression RELOP simple_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"rel_expr");
			$$->set_expression_type("int");
		    }
		;
				
simple_expression : term
        {
	    	outlog<<"At line no: "<<lines<<" simple_expression : term "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"simp_expr");
			$$->set_expression_type(get_node_type($1));
	    }
		| simple_expression ADDOP term 
		{
		    outlog<<"At line no: "<<lines<<" simple_expression : simple_expression ADDOP term "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"simp_expr");
			string left_type = get_node_type($1);
			string right_type = get_node_type($3);
			$$->set_expression_type(left_type == "float" || right_type == "float" ? "float" : "int");
		}
		;
				
term :	unary_expression //term can be void because of un_expr->factor
     	{
	    	outlog<<"At line no: "<<lines<<" term : unary_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"term");
			$$->set_expression_type(get_node_type($1));
		}
		|  term MULOP unary_expression
		{
	    	outlog<<"At line no: "<<lines<<" term : term MULOP unary_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"term");
			string left_type = get_node_type($1);
			string right_type = get_node_type($3);
			$$->set_expression_type(left_type == "float" || right_type == "float" ? "float" : "int");
		}
		;

unary_expression : ADDOP unary_expression  // un_expr can be void because of factor
		{
	    	outlog<<"At line no: "<<lines<<" unary_expression : ADDOP unary_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname(),"un_expr");
			$$->set_expression_type(get_node_type($2));
		}
		| NOT unary_expression 
		{
	    	outlog<<"At line no: "<<lines<<" unary_expression : NOT unary_expression "<<endl<<endl;
			outlog<<"!"<<$2->getname()<<endl<<endl;
			
			$$ = new symbol_info("!"+$2->getname(),"un_expr");
			$$->set_expression_type("int");
		     }
		| factor_info  
		{
	    	outlog<<"At line no: "<<lines<<" unary_expression : factor_info  "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"un_expr");
			$$->set_expression_type(get_node_type($1));
		}
		;
factor_info : factor
		{
			outlog<<"At line no: "<<lines<<" factor_info : factor "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
				
			$$ = new symbol_info($1->getname(),"fctr_info");
			$$->set_expression_type(get_node_type($1));
		}
		;
factor	: variable
		{
			outlog<<"At line no: "<<lines<<" factor : variable "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
				
			$$ = new symbol_info($1->getname(),"fctr");
			$$->set_data_type(get_node_type($1));
			$$->set_expression_type(get_node_type($1));
		}
		| ID LPAREN argument_list RPAREN
		{
			outlog<<"At line no: "<<lines<<" factor : ID LPAREN argument_list RPAREN "<<endl<<endl;
			outlog<<$1->getname()<<"("<<$3->getname()<<")"<<endl<<endl;

			symbol_info * function_symbol = lookup_symbol_by_name($1->getname());
			if (function_symbol != nullptr)
			{
				report_function_call_mismatches(function_symbol, $3);
			}

			$$ = new symbol_info($1->getname()+"("+$3->getname()+")","fctr");
			if (function_symbol != nullptr)
			{
				$$->set_data_type(function_symbol->get_data_type());
				$$->set_expression_type(function_symbol->get_data_type());
			}
		}
		| LPAREN expression RPAREN
		{
			outlog<<"At line no: "<<lines<<" factor : LPAREN expression RPAREN "<<endl<<endl;
			outlog<<"("<<$2->getname()<<")"<<endl<<endl;
			
			$$ = new symbol_info("("+$2->getname()+")","fctr");
			$$->set_data_type(get_node_type($2));
			$$->set_expression_type(get_node_type($2));
		}
		| CONST_INT 
		{
			outlog<<"At line no: "<<lines<<" factor : CONST_INT "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
				
			$$ = new symbol_info($1->getname(),"fctr");
			$$->set_data_type("int");
			$$->set_expression_type("int");
		}
		| CONST_FLOAT
		{
			outlog<<"At line no: "<<lines<<" factor : CONST_FLOAT "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
				
			$$ = new symbol_info($1->getname(),"fctr");
			$$->set_data_type("float");
			$$->set_expression_type("float");
		}
		| variable INCOP 
		{
			outlog<<"At line no: "<<lines<<" factor : variable INCOP "<<endl<<endl;
			outlog<<$1->getname()<<"++"<<endl<<endl;
				
			$$ = new symbol_info($1->getname()+"++","fctr");
			$$->set_data_type(get_node_type($1));
			$$->set_expression_type(get_node_type($1));
		}
		| variable DECOP
		{
			outlog<<"At line no: "<<lines<<" factor : variable DECOP "<<endl<<endl;
			outlog<<$1->getname()<<"--"<<endl<<endl;
				
			$$ = new symbol_info($1->getname()+"--","fctr");
			$$->set_data_type(get_node_type($1));
			$$->set_expression_type(get_node_type($1));
		}
		;
	
argument_list : arguments
		{
			outlog<<"At line no: "<<lines<<" argument_list : arguments "<<endl<<endl;
			$$->add_parameter(get_node_type($1), $1->getname());
			outlog<<$1->getname()<<endl<<endl;
						
			$$ = new symbol_info($1->getname(),"arg_list");
		}
		|
		{
			outlog<<"At line no: "<<lines<<" argument_list :  "<<endl<<endl;
			outlog<<""<<endl<<endl;
						
			$$ = new symbol_info("","arg_list");
		}
		;
	
arguments : arguments COMMA logic_expression
		{
			outlog<<"At line no: "<<lines<<" arguments : arguments COMMA logic_expression "<<endl<<endl;
			outlog<<$1->getname()<<","<<$3->getname()<<endl<<endl;
						
			$$ = new symbol_info($1->getname()+","+$3->getname(),"arg");
		}
	    | logic_expression
	    {
			outlog<<"At line no: "<<lines<<" arguments : logic_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
						
			$$ = new symbol_info($1->getname(),"arg");
		}
	    ;
 

%%

int main(int argc, char *argv[])
{
	if(argc != 2) 
	{
		outlog<<"Please input file name"<<endl;
		outlog.close();
		return 0;
	}
	yyin = fopen(argv[1], "r");
	outlog.open("my_log3.txt", ios::trunc);
	
	if(yyin == NULL)
	{
		outlog<<"Couldn't open file"<<endl;
		outlog.close();
		return 0;
	}

	symtable = new symbol_table(10);
	symtable->enter_scope();

	yyparse();
	
	outlog<<endl<<"Total lines: "<<lines<<endl;
	
	outlog.close();
	
	fclose(yyin);

	delete symtable;
	
	return 0;
}
