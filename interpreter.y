%{
	#include "absyn.h"
	#include <stdio.h>
	AST_Block* progBlock;

	extern int yylex();
	void yyerror(const char* s)
	{
		printf("Error: %s\n", s);
	}
%}

%union
{
	AST_Block* block;
	AST_Statement* stm;
	AST_Expression* exp;

	AST_Identifier* id;

	AST_ArrayIndex* index;
	AST_VariableDeclaration* var_declaration;

	std::string* string;
	int token;

	std::vector<shared_ptr<AST_VariableDeclaration>>* var_decl_list;
	std::vector<shared_ptr<AST_Expression>>* exp_list;
}

%token <string> TYPE_INT TYPE_DOUBLE TYPE_FLOAT TYPE_CHAR TYPE_BOOL TYPE_VOID TYPE_STRING IDENTIFIER INTEGER DOUBLE EXTERN LITERAL
%token <token> COMP_EQ COMP_NE COMP_GT COMP_GE COMP_LT COMP_LE ASSIGN_EQUAL
%token <token> LEFT_PAREN RIGHT_PAREN LEFT_BRACE RIGHT_BRACE COMMA DOT SEMICOLON LEFT_BRACKET RIGHT_BRACKET QUOTATION
%token <token> PLUS MINUS TIMES DIV AND OR XOR MOD NEG NOT SHIFT_LEFT SHIFT_RIGHT
%token <token> IF ELSE FOR WHILE RETURN STRUCT

%type <index> array_index
%type <id> id primary_typename array_typename struct_typename typename
%type <exp> numeric exp assign
%type <var_decl_list> func_declaration_args struct_members
%type <exp_list> call_args
%type <block> prog block stms 
%type <stm> stm var_declaration func_declaration struct_declaration if_stm for_stm while_stm
%type <token> comparison

%right SEMICOLON
%left PLUS MINUS
%left TIMES DIV MOD

%start prog

%%
prog : stms { progBlock = $1; }
				;
stms : stm { 
			$$ = new AST_Block(); 
			$$->statements->push_back(shared_ptr<AST_Statement>($1)); 
	 	}
	 | stms stm { 
	 	$1->statements->push_back(shared_ptr<AST_Statement>($2)); 
	 }
	;
stm : var_declaration 
	| func_declaration 
	| struct_declaration
	| exp { $$ = new AST_ExpressionStatement(shared_ptr<AST_Expression>($1)); }
	| RETURN exp { $$ = new AST_ReturnStatement(shared_ptr<AST_Expression>($2)); }
	| if_stm
	| for_stm
	| while_stm
	;

block : LEFT_BRACE stms RIGHT_BRACE { $$ = $2; }
	  | LEFT_BRACE RIGHT_BRACE { $$ = new AST_Block(); }
	;

primary_typename : TYPE_INT 	{ $$ = new AST_Identifier(*$1); 
								  $$->isType = true;  
							 	  delete $1; 
							 	}
				| TYPE_DOUBLE 	{ $$ = new AST_Identifier(*$1); 
								  $$->isType = true; 
								  delete $1; 
								}
				| TYPE_FLOAT 	{ $$ = new AST_Identifier(*$1); 
								  $$->isType = true; 
								  delete $1; 
								}
				| TYPE_CHAR 	{ $$ = new AST_Identifier(*$1); 
								  $$->isType = true; 
								  delete $1; 
								}
				| TYPE_BOOL 	{ $$ = new AST_Identifier(*$1); 
								  $$->isType = true; 
								  delete $1; 
								}
				| TYPE_VOID 	{ $$ = new AST_Identifier(*$1); 
								  $$->isType = true; 
								  delete $1; 
								}
				| TYPE_STRING   { $$ = new AST_Identifier(*$1); 
								  $$->isType = true; 
								  delete $1; 
								}

array_typename : primary_typename LEFT_BRACKET INTEGER RIGHT_BRACKET { 
					$1->isArray = true; 
					$1->arraySize->push_back(make_shared<AST_Integer>(atol($3->c_str()))); 
					$$ = $1; 
				}
				| array_typename LEFT_BRACKET INTEGER RIGHT_BRACKET {
					$1->arraySize->push_back(make_shared<AST_Integer>(atol($3->c_str())));
					$$ = $1;
				}

struct_typename : STRUCT id {
				$2->isType = true;
				$$ = $2;
			}

typename : primary_typename { $$ = $1; }
			| array_typename { $$ = $1; }
			| struct_typename { $$ = $1; }

var_declaration : typename id { 
					$$ = new AST_VariableDeclaration(shared_ptr<AST_Identifier>($1), 
													 shared_ptr<AST_Identifier>($2), 
													 nullptr); 
				 }
				 | typename id ASSIGN_EQUAL exp { 
				 	$$ = new AST_VariableDeclaration(shared_ptr<AST_Identifier>($1), 
												     shared_ptr<AST_Identifier>($2), 
												     shared_ptr<AST_Expression>($4)); 
				 }
				 | typename id ASSIGN_EQUAL LEFT_BRACKET call_args RIGHT_BRACKET {
					 $$ = new AST_ArrayInitialization(make_shared<AST_VariableDeclaration>(shared_ptr<AST_Identifier>($1), 
					 																	   shared_ptr<AST_Identifier>($2), 
					 																	   nullptr), 
					 								  shared_ptr<ExpressionList>($5));
				 }
				 ;

func_declaration : typename id LEFT_PAREN func_declaration_args RIGHT_PAREN block 
					{ $$ = new AST_FunctionDeclaration(shared_ptr<AST_Identifier>($1), 
													   shared_ptr<AST_Identifier>($2), 
													   shared_ptr<VariableList>($4), 
													   shared_ptr<AST_Block>($6));  
					}
					| EXTERN typename id LEFT_PAREN func_declaration_args RIGHT_PAREN 
					{ $$ = new AST_FunctionDeclaration(shared_ptr<AST_Identifier>($2), 
													   shared_ptr<AST_Identifier>($3), 
													   shared_ptr<VariableList>($5), 
													   nullptr, 
													   true); 
					}

func_declaration_args : /* none here */ { $$ = new VariableList(); }
					 | var_declaration { 
					   $$ = new VariableList(); 
					   $$->push_back(shared_ptr<AST_VariableDeclaration>($<var_declaration>1)); 
					 }
					 | func_declaration_args COMMA var_declaration 
					  { $1->push_back(shared_ptr<AST_VariableDeclaration>($<var_declaration>3)); }
					 ;

id : IDENTIFIER { $$ = new AST_Identifier(*$1); 
				  delete $1; }
			;

numeric : INTEGER { $$ = new AST_Integer(atol($1->c_str())); }
		| DOUBLE { $$ = new AST_Double(atof($1->c_str())); }
		;
exp : 	assign { $$ = $1; }	 
	 | id DOT id { 
	 		$$ = new AST_StructMember(shared_ptr<AST_Identifier>($1), shared_ptr<AST_Identifier>($3)); 
	 	}
	 | numeric
	 | id LEFT_PAREN call_args RIGHT_PAREN { 
	 		$$ = new AST_MethodCall(shared_ptr<AST_Identifier>($1), 
	 								shared_ptr<ExpressionList>($3)); 
	 	}
	 | id { $<id>$ = $1; }
	 | exp comparison exp { 
	 		$$ = new AST_BinaryOperator(shared_ptr<AST_Expression>($1), 
	 									$2, 
	 									shared_ptr<AST_Expression>($3)); 
	 	}
	 | exp MOD exp { 
	 		$$ = new AST_BinaryOperator(shared_ptr<AST_Expression>($1), 
	 									$2, 
	 									shared_ptr<AST_Expression>($3)); 
	 	}
	 | exp TIMES exp { 
	 		$$ = new AST_BinaryOperator(shared_ptr<AST_Expression>($1), 
	 									$2, 
	 									shared_ptr<AST_Expression>($3)); 
	 	}
	 | exp DIV exp { 
	 		$$ = new AST_BinaryOperator(shared_ptr<AST_Expression>($1), 
	 									$2, 
	 									shared_ptr<AST_Expression>($3)); 
	 	}
	 | exp PLUS exp { 
	 		$$ = new AST_BinaryOperator(shared_ptr<AST_Expression>($1), 
	 									$2, 
	 									shared_ptr<AST_Expression>($3)); 
	 	}
	 | exp MINUS exp { 
	 		$$ = new AST_BinaryOperator(shared_ptr<AST_Expression>($1), 
	 									$2, 
	 									shared_ptr<AST_Expression>($3)); 
	 	}
	 | LEFT_PAREN exp RIGHT_PAREN { $$ = $2; }
	 | MINUS exp { $$ = nullptr; /* todo */ }
	 | array_index { $$ = $1; }
	 | LITERAL { 
	 		$$ = new AST_Literal(*$1);
	 		delete $1; 
	 	}
	 ;

array_index : id LEFT_BRACKET exp RIGHT_BRACKET 
			{ $$ = new AST_ArrayIndex(shared_ptr<AST_Identifier>($1), shared_ptr<AST_Expression>($3)); }
			| array_index LEFT_BRACKET exp RIGHT_BRACKET { 	
				$1->expessions->push_back(shared_ptr<AST_Expression>($3));
				$$ = $1;
			}
			;

assign : id ASSIGN_EQUAL exp { 
				$$ = new AST_Assignment(shared_ptr<AST_Identifier>($1), shared_ptr<AST_Expression>($3)); 
			}
			| array_index ASSIGN_EQUAL exp {
				$$ = new AST_ArrayAssignment(shared_ptr<AST_ArrayIndex>($1), shared_ptr<AST_Expression>($3));
			}
			| id DOT id ASSIGN_EQUAL exp {
				auto member = make_shared<AST_StructMember>(shared_ptr<AST_Identifier>($1), 
															shared_ptr<AST_Identifier>($3)); 
				$$ = new AST_StructAssignment(member, shared_ptr<AST_Expression>($5)); 
			}

call_args : /* none here */ { $$ = new ExpressionList(); }
			| exp { 
				$$ = new ExpressionList(); 
				$$->push_back(shared_ptr<AST_Expression>($1)); 
			}
			| call_args COMMA exp { $1->push_back(shared_ptr<AST_Expression>($3)); }

comparison : COMP_EQ | COMP_NE | COMP_LT | COMP_LE | COMP_GT | COMP_GE | AND | OR | XOR | SHIFT_LEFT | SHIFT_RIGHT
					 ;
if_stm : IF exp block { $$ = new AST_IfStatement(shared_ptr<AST_Expression>($2), shared_ptr<AST_Block>($3)); }
		| IF exp block ELSE block { 
			$$ = new AST_IfStatement(shared_ptr<AST_Expression>($2), 
									shared_ptr<AST_Block>($3), 
									shared_ptr<AST_Block>($5)); 
		}
		| IF exp block ELSE if_stm { 
			auto tmp_block = new AST_Block(); 
			tmp_block->statements->push_back(shared_ptr<AST_Statement>($5)); 
			$$ = new AST_IfStatement(shared_ptr<AST_Expression>($2), 
									 shared_ptr<AST_Block>($3), 
									 shared_ptr<AST_Block>(tmp_block)); 
		}

for_stm : FOR LEFT_PAREN exp SEMICOLON exp SEMICOLON exp RIGHT_PAREN block { 
		 	$$ = new AST_ForStatement(shared_ptr<AST_Block>($9), 
		 							  shared_ptr<AST_Expression>($3), 
		 							  shared_ptr<AST_Expression>($5), 
		 							  shared_ptr<AST_Expression>($7)); 
		}
		
while_stm : WHILE LEFT_PAREN exp RIGHT_PAREN block { 
			$$ = new AST_ForStatement(shared_ptr<AST_Block>($5), 
									  nullptr, 
									  shared_ptr<AST_Expression>($3), 
									  nullptr); 
		}

struct_declaration : STRUCT id LEFT_BRACE struct_members RIGHT_BRACE {
			$$ = new AST_StructDeclaration(shared_ptr<AST_Identifier>($2), shared_ptr<VariableList>($4)); 
		}

struct_members : /* none here */ { $$ = new VariableList(); }
				| var_declaration { 
					$$ = new VariableList(); 
					$$->push_back(shared_ptr<AST_VariableDeclaration>($<var_declaration>1)); 
				}
				| struct_members var_declaration { 
					$1->push_back(shared_ptr<AST_VariableDeclaration>($<var_declaration>2)); 
				}

%%