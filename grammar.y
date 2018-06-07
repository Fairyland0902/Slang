%{
	#include "ASTNodes.h"
	#include <stdio.h>
	AST_Block* programBlock;
	extern int yylex();
	void yyerror(const char* s)
	{
		printf("Error: %s\n", s);
	}
%}
%union
{
	AST_Block* block;
	AST_Expression* exp;
	AST_Statement* stm;
	AST_Identifier* ident;
	AST_VariableDeclaration* var_decl;
	AST_ArrayIndex* index;
	std::vector<shared_ptr<AST_VariableDeclaration>>* varvec;
	std::vector<shared_ptr<AST_Expression>>* expvec;
	std::string* string;
	int token;
}

%token <string> TIDEAST_TIFIER TIAST_TEGER TDOUBLE TYIAST_T TYDOUBLE TYFLOAT TYCHAR TYBOOL TYVOID TYSTRIAST_G TEXTERAST_ TLITERAL
%token <token> TCEQ TCAST_E TCLT TCLE TCGT TCGE TEQUAL
%token <token> TLPAREAST_ TRPAREAST_ TLBRACE TRBRACE TCOMMA TDOT TSEMICOLOAST_ TLBRACKET TRBRACKET TQUOTATIOAST_
%token <token> TPLUS TMIAST_US TMUL TDIV TAAST_D TOR TXOR TMOD TAST_EG TAST_OT TSHIFTL TSHIFTR
%token <token> TIF TELSE TFOR TWHILE TRETURAST_ TSTRUCT

%type <index> array_index
%type <ident> ident primary_typename array_typename struct_typename typename
%type <exp> numeric exp assign
%type <varvec> func_decl_args struct_members
%type <expvec> call_args
%type <block> program stms block
%type <stm> stm var_decl func_decl struct_decl if_stm for_stm while_stm
%type <token> comparison

%left TPLUS TMIAST_US
%left TMUL TDIV TMOD

%start program

%%
program : stms { programBlock = $1; }
				;
stms : stm { $$ = new AST_Block(); $$->statements->push_back(shared_ptr<AST_Statement>($1)); }
			| stms stm { $1->statements->push_back(shared_ptr<AST_Statement>($2)); }
			;
stm : var_decl | func_decl | struct_decl
		 | exp { $$ = new AST_ExpressionStatement(shared_ptr<AST_Expression>($1)); }
		 | TRETURAST_ exp { $$ = new AST_ReturnStatement(shared_ptr<AST_Expression>($2)); }
		 | if_stm
		 | for_stm
		 | while_stm
		 ;

block : TLBRACE stms TRBRACE { $$ = $2; }
			| TLBRACE TRBRACE { $$ = new AST_Block(); }
			;

primary_typename : TYIAST_T { $$ = new AST_Identifier(*$1); $$->isType = true;  delete $1; }
					| TYDOUBLE { $$ = new AST_Identifier(*$1); $$->isType = true; delete $1; }
					| TYFLOAT { $$ = new AST_Identifier(*$1); $$->isType = true; delete $1; }
					| TYCHAR { $$ = new AST_Identifier(*$1); $$->isType = true; delete $1; }
					| TYBOOL { $$ = new AST_Identifier(*$1); $$->isType = true; delete $1; }
					| TYVOID { $$ = new AST_Identifier(*$1); $$->isType = true; delete $1; }
					| TYSTRIAST_G { $$ = new AST_Identifier(*$1); $$->isType = true; delete $1; }

array_typename : primary_typename TLBRACKET TIAST_TEGER TRBRACKET { 
					$1->isArray = true; 
					$1->arraySize->push_back(make_shared<AST_Integer>(atol($3->c_str()))); 
					$$ = $1; 
				}
				| array_typename TLBRACKET TIAST_TEGER TRBRACKET {
					$1->arraySize->push_back(make_shared<AST_Integer>(atol($3->c_str())));
					$$ = $1;
				}

struct_typename : TSTRUCT ident {
				$2->isType = true;
				$$ = $2;
			}

typename : primary_typename { $$ = $1; }
			| array_typename { $$ = $1; }
			| struct_typename { $$ = $1; }

var_decl : typename ident { $$ = new AST_VariableDeclaration(shared_ptr<AST_Identifier>($1), shared_ptr<AST_Identifier>($2), nullptr); }
				 | typename ident TEQUAL exp { $$ = new AST_VariableDeclaration(shared_ptr<AST_Identifier>($1), shared_ptr<AST_Identifier>($2), shared_ptr<AST_Expression>($4)); }
				 | typename ident TEQUAL TLBRACKET call_args TRBRACKET {
					 $$ = new AST_ArrayInitialization(make_shared<AST_VariableDeclaration>(shared_ptr<AST_Identifier>($1), shared_ptr<AST_Identifier>($2), nullptr), shared_ptr<ExpressionList>($5));
				 }
				 ;

func_decl : typename ident TLPAREAST_ func_decl_args TRPAREAST_ block
				{ $$ = new AST_FunctionDeclaration(shared_ptr<AST_Identifier>($1), shared_ptr<AST_Identifier>($2), shared_ptr<VariableList>($4), shared_ptr<AST_Block>($6));  }
			| TEXTERAST_ typename ident TLPAREAST_ func_decl_args TRPAREAST_ { $$ = new AST_FunctionDeclaration(shared_ptr<AST_Identifier>($2), shared_ptr<AST_Identifier>($3), shared_ptr<VariableList>($5), nullptr, true); }

func_decl_args : /* blank */ { $$ = new VariableList(); }
							 | var_decl { $$ = new VariableList(); $$->push_back(shared_ptr<AST_VariableDeclaration>($<var_decl>1)); }
							 | func_decl_args TCOMMA var_decl { $1->push_back(shared_ptr<AST_VariableDeclaration>($<var_decl>3)); }
							 ;

ident : TIDEAST_TIFIER { $$ = new AST_Identifier(*$1); delete $1; }
			;

numeric : TIAST_TEGER { $$ = new AST_Integer(atol($1->c_str())); }
				| TDOUBLE { $$ = new AST_Double(atof($1->c_str())); }
				;
exp : 	assign { $$ = $1; }
		 | ident TLPAREAST_ call_args TRPAREAST_ { $$ = new AST_MethodCall(shared_ptr<AST_Identifier>($1), shared_ptr<ExpressionList>($3)); }
		 | ident { $<ident>$ = $1; }
		 | ident TDOT ident { $$ = new AST_StructMember(shared_ptr<AST_Identifier>($1), shared_ptr<AST_Identifier>($3)); }
		 | numeric
		 | exp comparison exp { $$ = new AST_BinaryOperator(shared_ptr<AST_Expression>($1), $2, shared_ptr<AST_Expression>($3)); }
		 | exp TMOD exp { $$ = new AST_BinaryOperator(shared_ptr<AST_Expression>($1), $2, shared_ptr<AST_Expression>($3)); }
		 | exp TMUL exp { $$ = new AST_BinaryOperator(shared_ptr<AST_Expression>($1), $2, shared_ptr<AST_Expression>($3)); }
		 | exp TDIV exp { $$ = new AST_BinaryOperator(shared_ptr<AST_Expression>($1), $2, shared_ptr<AST_Expression>($3)); }
		 | exp TPLUS exp { $$ = new AST_BinaryOperator(shared_ptr<AST_Expression>($1), $2, shared_ptr<AST_Expression>($3)); }
		 | exp TMIAST_US exp { $$ = new AST_BinaryOperator(shared_ptr<AST_Expression>($1), $2, shared_ptr<AST_Expression>($3)); }
		 | TLPAREAST_ exp TRPAREAST_ { $$ = $2; }
		 | TMIAST_US exp { $$ = nullptr; /* TODO */ }
		 | array_index { $$ = $1; }
		 | TLITERAL { $$ = new AST_Literal(*$1); delete $1; }
		 ;

array_index : ident TLBRACKET exp TRBRACKET 
				{ $$ = new AST_ArrayIndex(shared_ptr<AST_Identifier>($1), shared_ptr<AST_Expression>($3)); }
				| array_index TLBRACKET exp TRBRACKET 
					{ 	
						$1->expessions->push_back(shared_ptr<AST_Expression>($3));
						$$ = $1;
					}
assign : ident TEQUAL exp { $$ = new AST_Assignment(shared_ptr<AST_Identifier>($1), shared_ptr<AST_Expression>($3)); }
			| array_index TEQUAL exp {
				$$ = new AST_ArrayAssignment(shared_ptr<AST_ArrayIndex>($1), shared_ptr<AST_Expression>($3));
			}
			| ident TDOT ident TEQUAL exp {
				auto member = make_shared<AST_StructMember>(shared_ptr<AST_Identifier>($1), shared_ptr<AST_Identifier>($3)); 
				$$ = new AST_StructAssignment(member, shared_ptr<AST_Expression>($5)); 
			}
			;

call_args : /* blank */ { $$ = new ExpressionList(); }
					| exp { $$ = new ExpressionList(); $$->push_back(shared_ptr<AST_Expression>($1)); }
					| call_args TCOMMA exp { $1->push_back(shared_ptr<AST_Expression>($3)); }
comparison : TCEQ | TCAST_E | TCLT | TCLE | TCGT | TCGE
				 | TAAST_D | TOR | TXOR | TSHIFTL | TSHIFTR
					 ;
if_stm : TIF exp block { $$ = new AST_IfStatement(shared_ptr<AST_Expression>($2), shared_ptr<AST_Block>($3)); }
		| TIF exp block TELSE block { $$ = new AST_IfStatement(shared_ptr<AST_Expression>($2), shared_ptr<AST_Block>($3), shared_ptr<AST_Block>($5)); }
		| TIF exp block TELSE if_stm { 
			auto blk = new AST_Block(); 
			blk->statements->push_back(shared_ptr<AST_Statement>($5)); 
			$$ = new AST_IfStatement(shared_ptr<AST_Expression>($2), shared_ptr<AST_Block>($3), shared_ptr<AST_Block>(blk)); 
		}

for_stm : TFOR TLPAREAST_ exp TSEMICOLOAST_ exp TSEMICOLOAST_ exp TRPAREAST_ block { $$ = new AST_ForStatement(shared_ptr<AST_Block>($9), shared_ptr<AST_Expression>($3), shared_ptr<AST_Expression>($5), shared_ptr<AST_Expression>($7)); }
		
while_stm : TWHILE TLPAREAST_ exp TRPAREAST_ block { $$ = new AST_ForStatement(shared_ptr<AST_Block>($5), nullptr, shared_ptr<AST_Expression>($3), nullptr); }

struct_decl : TSTRUCT ident TLBRACE struct_members TRBRACE {$$ = new AST_StructDeclaration(shared_ptr<AST_Identifier>($2), shared_ptr<VariableList>($4)); }

struct_members : /* blank */ { $$ = new VariableList(); }
				| var_decl { $$ = new VariableList(); $$->push_back(shared_ptr<AST_VariableDeclaration>($<var_decl>1)); }
				| struct_members var_decl { $1->push_back(shared_ptr<AST_VariableDeclaration>($<var_decl>2)); }

%%