%{
    #include <cstdio>
    #include <string>
    #include "absyn.h"

    AST_Block* programBlock;
    extern int yylex();
    extern int yyrow;
    extern int yycol;
    extern const char* yyfile;

    void yyerror(const char *s)
    {
    	fflush(stdout);
    	fprintf(stderr, "%s:%d:%d:\033[31m error:\033[0m %s\n", yyfile, yyrow, yycol, s);
    }
%}

%define parse.lac full
%define parse.error verbose

%union
{
    std::string* string;
    int token;

    AST_Block* block;
    AST_Statement* statement;
    AST_Expression* expression;
    AST_Identifier* identifier;
    AST_VariableDeclaration* variable_declaration;
    AST_ArrayIndex* index;

    std::vector<std::shared_ptr<AST_VariableDeclaration>>* variable_declaration_list;
    std::vector<std::shared_ptr<AST_Expression>>* expression_list;
}

%token<string> IDENTIFIER I_CONSTANT F_CONSTANT STRING_LITERAL FUNC_NAME
%token<token> PTR_OP INC_OP DEC_OP LEFT_OP RIGHT_OP LE_OP GE_OP EQ_OP NE_OP SIZEOF
%token<token> AND_OP OR_OP MUL_ASSIGN DIV_ASSIGN MOD_ASSIGN ADD_ASSIGN
%token<token> ADD_OP SUB_OP MUL_OP DIV_OP MOD_OP BIT_AND_OP BIT_OR_OP BIT_XOR_OP LT_OP GT_OP
%token<token> SUB_ASSIGN LEFT_ASSIGN RIGHT_ASSIGN AND_ASSIGN
%token<token> XOR_ASSIGN OR_ASSIGN
%token<token> TYPEDEF_NAME ENUMERATION_CONSTANT

%token<string> TYPEDEF EXTERN STATIC AUTO REGISTER INLINE
%token<string> CONST RESTRICT VOLATILE
%token<string> BOOL CHAR SHORT INT LONG SIGNED UNSIGNED FLOAT DOUBLE VOID
%token<string> COMPLEX IMAGINARY
%token<token> STRUCT UNION ENUM ELLIPSIS

%token<token> CASE DEFAULT IF ELSE SWITCH WHILE DO FOR GOTO CONTINUE BREAK RETURN

%token<string> ALIGNAS ALIGNOF ATOMIC GENERIC NORETURN STATIC_ASSERT THREAD_LOCAL

%type <index> array_index
%type <identifier> id primary_typename array_typename struct_typename typename
%type <expression> numeric expression assign
%type <variable_declaration_list> function_declaration_args struct_members
%type <expression_list> call_args
%type <block> program block translation_unit
%type <statement> external_declaration variable_declaration function_declaration struct_declaration if_statement for_statement while_statement
%type <token> comparison

%left ADD_OP SUB_OP
%left MUL_OP DIV_OP MOD_OP

%start program
%%

program
    : translation_unit {programBlock = $1;}
    ;

translation_unit
	: external_declaration {$$ = new AST_Block(); $$->statements->push_back(std::shared_ptr<AST_Statement>($1));}
	| translation_unit external_declaration {$1->statements->push_back(std::shared_ptr<AST_Statement>($2));}
	;

external_declaration
    : variable_declaration ';'
    | function_declaration
    | struct_declaration
    | expression {$$ = new AST_ExpressionStatement(std::shared_ptr<AST_Expression>($1));}
    | RETURN expression ';' {$$ = new AST_ReturnStatement(std::shared_ptr<AST_Expression>($2));}
    | if_statement
    | for_statement
    | while_statement
	;

block
    : '{' translation_unit '}' {$$ = $2;}
    | '{' '}' {$$ = new AST_Block();}
    ;

primary_typename
    : INT {$$ = new AST_Identifier(*$1); $$->isType = true; delete $1;}
    | DOUBLE {$$ = new AST_Identifier(*$1); $$->isType = true; delete $1;}
    | FLOAT {$$ = new AST_Identifier(*$1); $$->isType = true; delete $1;}
    | BOOL {$$ = new AST_Identifier(*$1); $$->isType = true; delete $1;}
    | VOID {$$ = new AST_Identifier(*$1); $$->isType = true; delete $1;}
    ;

array_typename
    : primary_typename '[' I_CONSTANT ']' {$1->isArray = true; $1->arraySize->push_back(make_shared<AST_Integer>(atol($3->c_str()))); $$ = $1;}
    | array_typename '[' I_CONSTANT ']' {$1->arraySize->push_back(make_shared<AST_Integer>(atol($3->c_str()))); $$ = $1;}
    ;

struct_typename
    : STRUCT id {$2->isType = true; $$ = $2;}
    ;

typename
    : primary_typename { $$ = $1; }
    | array_typename { $$ = $1; }
	| struct_typename { $$ = $1; }
    ;

variable_declaration
    : typename id {$$ = new AST_VariableDeclaration(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Identifier>($2), nullptr);}
	| typename id '=' expression {$$ = new AST_VariableDeclaration(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Identifier>($2), std::shared_ptr<AST_Expression>($4));}
    | typename id '=' '[' call_args ']' {$$ = new AST_ArrayInitialization(std::make_shared<AST_VariableDeclaration>(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Identifier>($2), nullptr), std::shared_ptr<AST_ExpressionList>($5));}
    ;

function_declaration
    : typename id '(' function_declaration_args ')' block {$$ = new AST_FunctionDeclaration(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Identifier>($2), std::shared_ptr<AST_VariableList>($4), std::shared_ptr<AST_Block>($6));}
    | EXTERN typename id '(' function_declaration_args ')' {$$ = new AST_FunctionDeclaration(std::shared_ptr<AST_Identifier>($2), std::shared_ptr<AST_Identifier>($3), std::shared_ptr<AST_VariableList>($5), nullptr, true);}
    ;

function_declaration_args
    : /* none here */ { $$ = new AST_VariableList(); }
    | variable_declaration {$$ = new AST_VariableList(); $$->push_back(std::shared_ptr<AST_VariableDeclaration>($<variable_declaration>1));}
    | function_declaration_args ',' variable_declaration {$1->push_back(std::shared_ptr<AST_VariableDeclaration>($<variable_declaration>3));}
    ;

id
    : IDENTIFIER {$$ = new AST_Identifier(*$1); delete $1; }
    ;

numeric
    : I_CONSTANT {$$ = new AST_Integer(atol($1->c_str())); delete $1;}
    | F_CONSTANT {$$ = new AST_Double(atof($1->c_str())); delete $1;}
	;

expression
    : assign {$$ = $1;}
    | id '.' id {$$ = new AST_StructMember(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Identifier>($3));}
    | numeric
    | id '(' call_args ')' {$$ = new AST_MethodCall(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_ExpressionList>($3));}
    | id {$<identifier>$ = $1;}
    | expression comparison expression {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3));}
    | expression MOD_OP expression {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3));}
    | expression MUL_OP expression {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3));}
    | expression DIV_OP expression {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3));}
	| expression ADD_OP expression {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3));}
    | expression SUB_OP expression {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3));}
    | '(' expression ')' {$$ = $2;}
    | '-' expression {$$ = nullptr; /* todo */}
    | array_index {$$ = $1;}
    | STRING_LITERAL {$$ = new AST_Literal(*$1); delete $1;}
    ;

array_index
    : id '[' expression ']' {$$ = new AST_ArrayIndex(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Expression>($3));}
    | array_index '[' expression ']' {$1->expressions->push_back(std::shared_ptr<AST_Expression>($3)); $$ = $1;}
    ;

assign
    : id '=' expression {$$ = new AST_Assignment(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Expression>($3));}
    | array_index '=' expression {$$ = new AST_ArrayAssignment(std::shared_ptr<AST_ArrayIndex>($1), std::shared_ptr<AST_Expression>($3));}
    | id '.' id '=' expression {auto member = std::make_shared<AST_StructMember>(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Identifier>($3)); $$ = new AST_StructAssignment(member, std::shared_ptr<AST_Expression>($5));}
    ;

call_args
    : /* none here */ {$$ = new AST_ExpressionList();}
    | expression {$$ = new AST_ExpressionList(); $$->push_back(std::shared_ptr<AST_Expression>($1));}
    | call_args ',' expression {$1->push_back(std::shared_ptr<AST_Expression>($3));}
    ;

comparison
    : EQ_OP | NE_OP | LE_OP | GE_OP | RIGHT_OP | LEFT_OP | LT_OP | GT_OP | BIT_AND_OP | BIT_OR_OP | BIT_XOR_OP
    ;

if_statement
    : IF expression block {$$ = new AST_IfStatement(std::shared_ptr<AST_Expression>($2), std::shared_ptr<AST_Block>($3));}
    | IF expression block ELSE block {$$ = new AST_IfStatement(std::shared_ptr<AST_Expression>($2), std::shared_ptr<AST_Block>($3), std::shared_ptr<AST_Block>($5));}
    | IF expression block ELSE if_statement {auto tmp_block = new AST_Block(); tmp_block->statements->push_back(std::shared_ptr<AST_Statement>($5)); $$ = new AST_IfStatement(std::shared_ptr<AST_Expression>($2), std::shared_ptr<AST_Block>($3), std::shared_ptr<AST_Block>(tmp_block));}
    ;

for_statement
    : FOR '(' expression ';' expression ';' expression ')' block {$$ = new AST_ForStatement(std::shared_ptr<AST_Block>($9), std::shared_ptr<AST_Expression>($3), std::shared_ptr<AST_Expression>($5), std::shared_ptr<AST_Expression>($7));}
    ;

while_statement
    : WHILE '(' expression ')' block {$$ = new AST_ForStatement(std::shared_ptr<AST_Block>($5), nullptr, std::shared_ptr<AST_Expression>($3), nullptr);}

struct_declaration
    : STRUCT id '{' struct_members '}' {$$ = new AST_StructDeclaration(std::shared_ptr<AST_Identifier>($2), std::shared_ptr<AST_VariableList>($4));}

struct_members
    : /* none here */ { $$ = new AST_VariableList(); }
    | variable_declaration {$$ = new AST_VariableList(); $$->push_back(std::shared_ptr<AST_VariableDeclaration>($<variable_declaration>1));}
    | struct_members variable_declaration {$1->push_back(std::shared_ptr<AST_VariableDeclaration>($<variable_declaration>2));}
%%
