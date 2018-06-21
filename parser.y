%{
    #include <iostream>
    #include <cstdio>
    #include <string>
    #include "absyn.h"

    AST_Block* programBlock;
    bool emptyFile;
    extern int yylex();
    extern int yyrow;
    extern int yycol;
    extern const char* yyfile;

    void yyerror(const char *s)
    {
    	fflush(stdout);
    	fprintf(stderr, "\033[1m%s:%d:%d:\033[1;31m error: \033[0m", yyfile, yyrow, yycol);
    	fprintf(stderr, "\033[1m%s\033[0m\n", s);
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

%type <token> assignment_operator
%type <index> array_index
%type <identifier> id primary_typename struct_typename type_specifier
%type <expression> constant string
%type <expression> expression assignment_expression logical_or_expression logical_and_expression inclusive_or_expression exclusive_or_expression and_expression
%type <expression> equality_expression relational_expression shift_expression additive_expression multiplicative_expression
%type <expression> unary_expression postfix_expression primary_expression
%type <variable_declaration> array_declaration
%type <variable_declaration_list> parameter_list struct_declaration_list
%type <expression_list> argument_expression_list
%type <block> program translation_unit local_statement_list block
%type <statement> statement local_statement variable_declaration function_declaration struct_declaration expression_statement selection_statement iteration_statement jump_statement

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%start program
%%

program
    : /* empty file */ {emptyFile = true; return 0;}
    | translation_unit {programBlock = $1;}
    ;

translation_unit
    : statement                     {$$ = new AST_Block(); $$->col = yycol; $$->row = yyrow; $$->statements->push_back(std::shared_ptr<AST_Statement>($1));}
    | translation_unit statement    {$1->statements->push_back(std::shared_ptr<AST_Statement>($2)); $$ = $1;}
    ;

statement
    : variable_declaration ';'  {$1->isGlobal = true; $$ = $1;}
    | function_declaration      {$1->isGlobal = true; $$ = $1;}
    | struct_declaration        {$1->isGlobal = true; $$ = $1;}
    | error ';'                 {yyerrok; yyclearin;}
    ;

primary_typename
    : INT       {$$ = new AST_Identifier(*$1); $$->col = yycol; $$->row = yyrow; $$->isType = true; delete $1;}
    | DOUBLE    {$$ = new AST_Identifier(*$1); $$->col = yycol; $$->row = yyrow; $$->isType = true; delete $1;}
    | FLOAT     {$$ = new AST_Identifier(*$1); $$->col = yycol; $$->row = yyrow; $$->isType = true; delete $1;}
    | CHAR      {$$ = new AST_Identifier(*$1); $$->col = yycol; $$->row = yyrow; $$->isType = true; delete $1;}
    | BOOL      {$$ = new AST_Identifier(*$1); $$->col = yycol; $$->row = yyrow; $$->isType = true; delete $1;}
    | VOID      {$$ = new AST_Identifier(*$1); $$->col = yycol; $$->row = yyrow; $$->isType = true; delete $1;}
    ;

struct_typename
    : STRUCT id {$2->isType = true; $$ = $2;}
    ;

type_specifier
    : primary_typename  {$$ = $1;}
    | struct_typename   {$$ = $1;}
    ;

array_declaration
    : type_specifier id '[' I_CONSTANT ']'  {$1->isArray = true; $1->arraySize->push_back(make_shared<AST_Integer>(atol($4->c_str()))); $$ = new AST_VariableDeclaration(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Identifier>($2), nullptr); $$->col = yycol; $$->row = yyrow;}
    | array_declaration '[' I_CONSTANT ']'  {$1->type->arraySize->push_back(make_shared<AST_Integer>(atol($3->c_str()))); $$ = $1;}
    ;

variable_declaration
    : type_specifier id                                         {$$ = new AST_VariableDeclaration(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Identifier>($2), nullptr); $$->col = yycol; $$->row = yyrow;}
    | type_specifier id '=' expression                          {$$ = new AST_VariableDeclaration(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Identifier>($2), std::shared_ptr<AST_Expression>($4)); $$->col = yycol; $$->row = yyrow;}
    | array_declaration                                         {$$ = $1;}
    | array_declaration '=' '{' argument_expression_list '}'    {$$ = new AST_ArrayInitialization(std::shared_ptr<AST_VariableDeclaration>($1), std::shared_ptr<AST_ExpressionList>($4)); $$->col = yycol; $$->row = yyrow;}
    ;

function_declaration
    : type_specifier id '(' parameter_list ')' block        {$$ = new AST_FunctionDeclaration(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Identifier>($2), std::shared_ptr<AST_VariableList>($4), std::shared_ptr<AST_Block>($6)); $$->col = yycol; $$->row = yyrow;}
    | type_specifier id '(' parameter_list ')' ';'          {$$ = new AST_FunctionDeclaration(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Identifier>($2), std::shared_ptr<AST_VariableList>($4), nullptr, true); $$->col = yycol; $$->row = yyrow;}
    | EXTERN type_specifier id '(' parameter_list ')' ';'   {$$ = new AST_FunctionDeclaration(std::shared_ptr<AST_Identifier>($2), std::shared_ptr<AST_Identifier>($3), std::shared_ptr<AST_VariableList>($5), nullptr, true); $$->col = yycol; $$->row = yyrow;}
    ;

parameter_list
    : /* none here */                           {$$ = new AST_VariableList();}
    | variable_declaration                      {$$ = new AST_VariableList(); $$->push_back(std::shared_ptr<AST_VariableDeclaration>($<variable_declaration>1));}
    | parameter_list ',' variable_declaration   {$1->push_back(std::shared_ptr<AST_VariableDeclaration>($<variable_declaration>3)); $$ = $1;}
    ;

struct_declaration
    : STRUCT id '{' struct_declaration_list '}' ';' {$$ = new AST_StructDeclaration(std::shared_ptr<AST_Identifier>($2), std::shared_ptr<AST_VariableList>($4)); $$->col = yycol; $$->row = yyrow;}
    ;

struct_declaration_list
    : variable_declaration ';'                          {$$ = new AST_VariableList(); $$->push_back(std::shared_ptr<AST_VariableDeclaration>($<variable_declaration>1));}
    | struct_declaration_list variable_declaration ';'  {$1->push_back(std::shared_ptr<AST_VariableDeclaration>($<variable_declaration>2)); $$ = $1;}
    ;

expression_statement
    : ';'               {AST_Expression* empty = new AST_Expression(); $$ = new AST_ExpressionStatement(std::shared_ptr<AST_Expression>(empty)); $$->col = yycol; $$->row = yyrow;}
    | expression ';'    {$$ = new AST_ExpressionStatement(std::shared_ptr<AST_Expression>($1)); $$->col = yycol; $$->row = yyrow;}
    ;

selection_statement
    : IF '(' expression ')' block ELSE block                {$$ = new AST_IfStatement(std::shared_ptr<AST_Expression>($3), std::shared_ptr<AST_Block>($5), std::shared_ptr<AST_Block>($7)); $$->col = yycol; $$->row = yyrow;}
    | IF '(' expression ')' block ELSE selection_statement  {auto tmp_block = new AST_Block(); tmp_block->col = yycol; tmp_block->row = yyrow; tmp_block->statements->push_back(std::shared_ptr<AST_Statement>($7)); $$ = new AST_IfStatement(std::shared_ptr<AST_Expression>($3), std::shared_ptr<AST_Block>($5), std::shared_ptr<AST_Block>(tmp_block)); $$->col = yycol; $$->row = yyrow;}
    | IF '(' expression ')' block %prec LOWER_THAN_ELSE     {$$ = new AST_IfStatement(std::shared_ptr<AST_Expression>($3), std::shared_ptr<AST_Block>($5)); $$->col = yycol; $$->row = yyrow;}
    ;

iteration_statement
    : WHILE '(' expression ')' block                                {$$ = new AST_ForStatement(std::shared_ptr<AST_Block>($5), nullptr, std::shared_ptr<AST_Expression>($3), nullptr); $$->col = yycol; $$->row = yyrow;}
    | FOR '(' expression ';' expression ';' expression ')' block    {$$ = new AST_ForStatement(std::shared_ptr<AST_Block>($9), std::shared_ptr<AST_Expression>($3), std::shared_ptr<AST_Expression>($5), std::shared_ptr<AST_Expression>($7)); $$->col = yycol; $$->row = yyrow;}
    ;

jump_statement
    : RETURN ';'            {AST_Expression* empty = new AST_Expression(); $$ = new AST_ReturnStatement(std::shared_ptr<AST_Expression>(empty)); $$->col = yycol; $$->row = yyrow;}
    | RETURN expression ';' {$$ = new AST_ReturnStatement(std::shared_ptr<AST_Expression>($2)); $$->col = yycol; $$->row = yyrow;}
    ;

local_statement_list
    : local_statement                       {$$ = new AST_Block(); $$->col = yycol; $$->row = yyrow; $$->statements->push_back(std::shared_ptr<AST_Statement>($1));}
    | local_statement_list local_statement  {$1->statements->push_back(std::shared_ptr<AST_Statement>($2)); $$ = $1;}
    ;

local_statement
    : variable_declaration ';'  {$$ = $1;}
    | expression_statement      {$$ = $1;}
    | selection_statement       {$$ = $1;}
    | iteration_statement       {$$ = $1;}
    | jump_statement            {$$ = $1;}
    | error ';'                 {yyerrok; yyclearin;}
    ;

block
    : '{' local_statement_list '}'  {$$ = $2;}
    | '{' '}'                       {$$ = new AST_Block(); $$->col = yycol; $$->row = yyrow;}
    ;

id
    : IDENTIFIER {$$ = new AST_Identifier(*$1); $$->col = yycol; $$->row = yyrow; delete $1;}
    ;

constant
    : I_CONSTANT {$$ = new AST_Integer(atol($1->c_str())); $$->col = yycol; $$->row = yyrow; delete $1;}
    | F_CONSTANT {$$ = new AST_Double(atof($1->c_str())); $$->col = yycol; $$->row = yyrow; delete $1;}
    ;

string
    : STRING_LITERAL {std::string temp = $1->substr(1, $1->length() - 2); $$ = new AST_Literal(temp); $$->col = yycol; $$->row = yyrow; delete $1;}
    ;

expression
    : assignment_expression {$$ = $1;}
    ;

assignment_expression
    : logical_or_expression                                         {$$ = $1;}
    | id '=' assignment_expression                                  {$$ = new AST_Assignment(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    | array_index '=' assignment_expression                         {$$ = new AST_ArrayAssignment(std::shared_ptr<AST_ArrayIndex>($1), std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    | id '.' id '=' assignment_expression                           {auto member = std::make_shared<AST_StructMember>(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Identifier>($3)); $$ = new AST_StructAssignment(member, std::shared_ptr<AST_Expression>($5)); $$->col = yycol; $$->row = yyrow;}
    | array_index '.' id '=' assignment_expression                  {auto member = std::make_shared<AST_StructMember>(std::shared_ptr<AST_Identifier>($1->arrayName), std::shared_ptr<AST_Identifier>($3), std::shared_ptr<AST_ArrayIndex>($1), true); $$ = new AST_StructAssignment(member, std::shared_ptr<AST_Expression>($5)); $$->col = yycol; $$->row = yyrow;}
    | id assignment_operator assignment_expression                  {auto expr = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$ = new AST_Assignment(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Expression>(expr)); $$->col = yycol; $$->row = yyrow;}
    | array_index assignment_operator assignment_expression         {auto expr = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$ = new AST_ArrayAssignment(std::shared_ptr<AST_ArrayIndex>($1), std::shared_ptr<AST_Expression>(expr)); $$->col = yycol; $$->row = yyrow;}
    | id '.' id assignment_operator assignment_expression           {auto expr = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $4, std::shared_ptr<AST_Expression>($3)); auto member = std::make_shared<AST_StructMember>(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Identifier>($3)); $$ = new AST_StructAssignment(member, std::shared_ptr<AST_Expression>(expr)); $$->col = yycol; $$->row = yyrow;}
    | array_index '.' id assignment_operator assignment_expression  {auto expr = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $4, std::shared_ptr<AST_Expression>($3)); auto member = std::make_shared<AST_StructMember>(std::shared_ptr<AST_Identifier>($1->arrayName), std::shared_ptr<AST_Identifier>($3), std::shared_ptr<AST_ArrayIndex>($1), true); $$ = new AST_StructAssignment(member, std::shared_ptr<AST_Expression>(expr)); $$->col = yycol; $$->row = yyrow;}
    ;

assignment_operator
	: MUL_ASSIGN    {$$ = MUL_OP;}
	| DIV_ASSIGN    {$$ = DIV_OP;}
	| MOD_ASSIGN    {$$ = MOD_OP;}
	| ADD_ASSIGN    {$$ = ADD_OP;}
	| SUB_ASSIGN    {$$ = SUB_OP;}
	| LEFT_ASSIGN   {$$ = LEFT_OP;}
	| RIGHT_ASSIGN  {$$ = RIGHT_OP;}
	| AND_ASSIGN    {$$ = BIT_AND_OP;}
	| OR_ASSIGN     {$$ = BIT_OR_OP;}
	| XOR_ASSIGN    {$$ = BIT_XOR_OP;}
	;

logical_or_expression
    : logical_and_expression                                {$$ = $1;}
    | logical_or_expression OR_OP logical_and_expression    {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    ;

logical_and_expression
    : inclusive_or_expression                               {$$ = $1;}
    | logical_and_expression AND_OP inclusive_or_expression {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    ;

inclusive_or_expression
    : exclusive_or_expression                                   {$$ = $1;}
    | inclusive_or_expression BIT_OR_OP exclusive_or_expression {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    ;

exclusive_or_expression
    : and_expression                                    {$$ = $1;}
    | exclusive_or_expression BIT_XOR_OP and_expression {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    ;

and_expression
    : equality_expression                           {$$ = $1;}
    | and_expression BIT_AND_OP equality_expression {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    ;

equality_expression
    : relational_expression                             {$$ = $1;}
    | equality_expression EQ_OP relational_expression   {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    | equality_expression NE_OP relational_expression   {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    ;

relational_expression
    : shift_expression                              {$$ = $1;}
    | relational_expression LT_OP shift_expression  {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    | relational_expression GT_OP shift_expression  {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    | relational_expression LE_OP shift_expression  {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    | relational_expression GE_OP shift_expression  {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    ;

shift_expression
    : additive_expression                           {$$ = $1;}
    | shift_expression LEFT_OP additive_expression  {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    | shift_expression RIGHT_OP additive_expression {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    ;

additive_expression
    : multiplicative_expression                             {$$ = $1;}
    | additive_expression ADD_OP multiplicative_expression  {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    | additive_expression SUB_OP multiplicative_expression  {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    ;

multiplicative_expression
    : unary_expression                                  {$$ = $1;}
    | multiplicative_expression MUL_OP unary_expression {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    | multiplicative_expression DIV_OP unary_expression {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    | multiplicative_expression MOD_OP unary_expression {$$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), $2, std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    ;

unary_expression
    : postfix_expression        {$$ = $1;}
    | SUB_OP postfix_expression {auto zero = new AST_Integer(0); $$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>(zero), SUB_OP, std::shared_ptr<AST_Expression>($2)); $$->col = yycol; $$->row = yyrow;}
    | '~' postfix_expression    {auto neg = new AST_Integer(0xffffffffffffffff); $$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>(neg), BIT_XOR_OP, std::shared_ptr<AST_Expression>($2)); $$->col = yycol; $$->row = yyrow;}
    | '!' postfix_expression    {auto neg = new AST_Integer(0xffffffffffffffff); $$ = new AST_BinaryOperator(std::shared_ptr<AST_Expression>(neg), BIT_XOR_OP, std::shared_ptr<AST_Expression>($2)); $$->col = yycol; $$->row = yyrow;}
    | INC_OP id                 {auto one = new AST_Integer(1); auto inc = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($2), ADD_OP, std::shared_ptr<AST_Expression>(one)); $$ = new AST_Assignment(std::shared_ptr<AST_Identifier>($2), std::shared_ptr<AST_Expression>(inc)); $$->col = yycol; $$->row = yyrow;}
    | DEC_OP id                 {auto one = new AST_Integer(1); auto dec = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($2), SUB_OP, std::shared_ptr<AST_Expression>(one)); $$ = new AST_Assignment(std::shared_ptr<AST_Identifier>($2), std::shared_ptr<AST_Expression>(dec)); $$->col = yycol; $$->row = yyrow;}
    ;

postfix_expression
    : primary_expression                    {$$ = $1;}
    | array_index                           {$$ = $1;}
    | id '.' id                             {$$ = new AST_StructMember(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Identifier>($3)); $$->col = yycol; $$->row = yyrow;}
    | array_index '.' id                    {$$ = new AST_StructMember(std::shared_ptr<AST_Identifier>($1->arrayName), std::shared_ptr<AST_Identifier>($3), std::shared_ptr<AST_ArrayIndex>($1), true); $$->col = yycol; $$->row = yyrow;}
    | id '(' ')'                            {$$ = new AST_MethodCall(std::shared_ptr<AST_Identifier>($1)); $$->col = yycol; $$->row = yyrow;}
    | id '(' argument_expression_list ')'   {$$ = new AST_MethodCall(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_ExpressionList>($3)); $$->col = yycol; $$->row = yyrow;}
    | id INC_OP                             {auto one = new AST_Integer(1); auto inc = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), ADD_OP, std::shared_ptr<AST_Expression>(one)); $$ = new AST_Assignment(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Expression>(inc)); $$->col = yycol; $$->row = yyrow;}
    | id DEC_OP                             {auto one = new AST_Integer(1); auto dec = new AST_BinaryOperator(std::shared_ptr<AST_Expression>($1), SUB_OP, std::shared_ptr<AST_Expression>(one)); $$ = new AST_Assignment(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Expression>(dec)); $$->col = yycol; $$->row = yyrow;}
    ;

primary_expression
    : id                    {$$ = $1;}
    | constant              {$$ = $1;}
    | string                {$$ = $1;}
    | '(' expression ')'    {$$ = $2;}
    ;

array_index
    : id '[' expression ']'             {$$ = new AST_ArrayIndex(std::shared_ptr<AST_Identifier>($1), std::shared_ptr<AST_Expression>($3)); $$->col = yycol; $$->row = yyrow;}
    | array_index '[' expression ']'    {$1->expressions->push_back(std::shared_ptr<AST_Expression>($3)); $$ = $1;}
    ;

argument_expression_list
    : /* none here */                           {$$ = new AST_ExpressionList();}
    | expression                                {$$ = new AST_ExpressionList(); $$->push_back(std::shared_ptr<AST_Expression>($1));}
    | argument_expression_list ',' expression   {$1->push_back(std::shared_ptr<AST_Expression>($3)); $$ = $1;}
    ;

%%
