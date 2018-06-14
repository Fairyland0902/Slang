%e  1019
%p  2807
%n  371
%k  284
%a  1213
%o  1117

O   [0-7]
D   [0-9]
NZ  [1-9]
L   [a-zA-Z_]
A   [a-zA-Z_0-9]
H   [a-fA-F0-9]
HP  (0[xX])
E   ([Ee][+-]?{D}+)
P   ([Pp][+-]?{D}+)
FS  (f|F|l|L)
IS  (((u|U)(l|L|ll|LL)?)|((l|L|ll|LL)(u|U)?))
CP  (u|U|L)
SP  (u8|u|U|L)
ES  (\\(['"\?\\abfnrtv]|[0-7]{1,3}|x[a-fA-F0-9]+))
WS  [ \t\v\n\f]

%{
#include <cstdio>
#include <iostream>
#include "absyn.h"
#include "parser.h"

extern void yyerror(const char *);  /* prints grammar violation message */

#define SAVE_TOKEN yylval.string = new std::string(yytext)
#define TOKEN(t) ( yylval.token = t)

static void comment(void);

/*
 * The stream the lexer will read from.
 * Declare it as extern.
 */
extern std::istream* lexer_ins_;

/*
 * Define YY_INPUT to get from lexer_ins_
 * This definition mirrors the functionality of the default
 * interactive YY_INPUT
 */
#define YY_INPUT(buf, result, max_size)  \
  result = 0; \
  while (1) { \
    int c = lexer_ins_->get(); \
    if (lexer_ins_->eof()) { \
      break; \
    } \
    buf[result++] = c; \
    if (result == max_size || c == '\n') { \
      break; \
    } \
  }
%}

%option debug

%%
"/*"                                { comment(); }
"//".*                              { /* consume //-comment */ }

"auto"                              { return TOKEN(AUTO); }
"break"                             { return TOKEN(BREAK); }
"case"                              { return TOKEN(CASE); }
"char"                              { SAVE_TOKEN; return (CHAR); }
"const"                             { SAVE_TOKEN; return (CONST); }
"continue"                          { return TOKEN(CONTINUE); }
"default"                           { return TOKEN(DEFAULT); }
"do"                                { return TOKEN(DO); }
"double"                            { SAVE_TOKEN; return (DOUBLE); }
"else"                              { return TOKEN(ELSE); }
"enum"                              { return TOKEN(ENUM); }
"extern"                            { SAVE_TOKEN; return (EXTERN); }
"float"                             { SAVE_TOKEN; return(FLOAT); }
"for"                               { return TOKEN(FOR); }
"goto"                              { return TOKEN(GOTO); }
"if"                                { return TOKEN(IF); }
"inline"                            { SAVE_TOKEN; return (INLINE); }
"int"                               { SAVE_TOKEN; return (INT); }
"long"                              { SAVE_TOKEN; return (LONG); }
"register"                          { SAVE_TOKEN; return (REGISTER); }
"restrict"                          { SAVE_TOKEN; return (RESTRICT); }
"return"                            { return TOKEN(RETURN); }
"short"                             { SAVE_TOKEN; return (SHORT); }
"signed"                            { SAVE_TOKEN; return (SIGNED); }
"sizeof"                            { return TOKEN(SIZEOF); }
"static"                            { SAVE_TOKEN; return(STATIC); }
"struct"                            { return TOKEN(STRUCT); }
"switch"                            { return TOKEN(SWITCH); }
"typedef"                           { SAVE_TOKEN; return (TYPEDEF); }
"union"                             { return TOKEN(UNION); }
"unsigned"                          { SAVE_TOKEN; return (UNSIGNED); }
"void"                              { SAVE_TOKEN; return (VOID); }
"volatile"                          { return TOKEN(VOLATILE); }
"while"                             { return TOKEN(WHILE); }
"_Alignas"                          { SAVE_TOKEN; return (ALIGNAS); }
"_Alignof"                          { SAVE_TOKEN; return (ALIGNOF); }
"_Atomic"                           { SAVE_TOKEN; return (ATOMIC); }
"_Bool"                             { SAVE_TOKEN; return (BOOL); }
"_Complex"                          { SAVE_TOKEN; return (COMPLEX); }
"_Generic"                          { SAVE_TOKEN; return (GENERIC); }
"_Imaginary"                        { SAVE_TOKEN; return (IMAGINARY); }
"_Noreturn"                         { SAVE_TOKEN; return (NORETURN); }
"_Static_assert"                    { SAVE_TOKEN; return (STATIC_ASSERT); }
"_Thread_local"                     { SAVE_TOKEN; return (THREAD_LOCAL); }
"__func__"                          { SAVE_TOKEN; return (FUNC_NAME); }

{L}{A}*                             { SAVE_TOKEN; return (IDENTIFIER); /* Identifier */ }

{HP}{H}+{IS}?                       { SAVE_TOKEN; return (I_CONSTANT); /* Integer */ }
{NZ}{D}*{IS}?                       { SAVE_TOKEN; return (I_CONSTANT); /* Integer */ }
"0"{O}*{IS}?                        { SAVE_TOKEN; return (I_CONSTANT); /* Integer */ }
{CP}?"'"([^'\\\n]|{ES})+"'"         { SAVE_TOKEN; return (I_CONSTANT); /* Integer */ }

{D}+{E}{FS}?                        { SAVE_TOKEN; return (F_CONSTANT); /* Floating Point */ }
{D}*"."{D}+{E}?{FS}?                { SAVE_TOKEN; return (F_CONSTANT); /* Floating Point */ }
{D}+"."{E}?{FS}?                    { SAVE_TOKEN; return (F_CONSTANT); /* Floating Point */ }
{HP}{H}+{P}{FS}?                    { SAVE_TOKEN; return (F_CONSTANT); /* Floating Point */ }
{HP}{H}*"."{H}+{P}{FS}?             { SAVE_TOKEN; return (F_CONSTANT); /* Floating Point */ }
{HP}{H}+"."{P}{FS}?                 { SAVE_TOKEN; return (F_CONSTANT); /* Floating Point */ }

({SP}?\"([^"\\\n]|{ES})*\"{WS}*)+   { SAVE_TOKEN; return (STRING_LITERAL); /* String Literal */ }

"..."                               { return TOKEN(ELLIPSIS); }
">>="                               { return TOKEN(RIGHT_ASSIGN); }
"<<="                               { return TOKEN(LEFT_ASSIGN); }
"+="                                { return TOKEN(ADD_ASSIGN); }
"-="                                { return TOKEN(SUB_ASSIGN); }
"*="                                { return TOKEN(MUL_ASSIGN); }
"/="                                { return TOKEN(DIV_ASSIGN); }
"%="                                { return TOKEN(MOD_ASSIGN); }
"&="                                { return TOKEN(AND_ASSIGN); }
"^="                                { return TOKEN(XOR_ASSIGN); }
"|="                                { return TOKEN(OR_ASSIGN); }
">>"                                { return TOKEN(RIGHT_OP); }
"<<"                                { return TOKEN(LEFT_OP); }
"++"                                { return TOKEN(INC_OP); }
"--"                                { return TOKEN(DEC_OP); }
"->"                                { return TOKEN(PTR_OP); }
"&&"                                { return TOKEN(AND_OP); }
"||"                                { return TOKEN(OR_OP); }
"<="                                { return TOKEN(LE_OP); }
">="                                { return TOKEN(GE_OP); }
"=="                                { return TOKEN(EQ_OP); }
"!="                                { return TOKEN(NE_OP); }
";"                                 { return ';'; }
("{"|"<%")                          { return '{'; }
("}"|"%>")                          { return '}'; }
","                                 { return ','; }
":"                                 { return ':'; }
"="                                 { return '='; }
"("                                 { return '('; }
")"                                 { return ')'; }
("["|"<:")                          { return '['; }
("]"|":>")                          { return ']'; }
"."                                 { return '.'; }
"&"                                 { return TOKEN(BIT_AND_OP); }
"!"                                 { return '!'; }
"~"                                 { return '~'; }
"-"                                 { return TOKEN(SUB_OP); }
"+"                                 { return TOKEN(ADD_OP); }
"*"                                 { return TOKEN(MUL_OP); }
"/"                                 { return TOKEN(DIV_OP); }
"%"                                 { return TOKEN(MOD_OP); }
"<"                                 { return TOKEN(LT_OP); }
">"                                 { return TOKEN(GT_OP); }
"^"                                 { return TOKEN(BIT_XOR_OP); }
"|"                                 { return TOKEN(BIT_OR_OP); }
"?"                                 { return '?'; }

%%

int yywrap(void)        /* called at end of input */
{
    return 1;           /* terminate now */
}

static void comment(void)
{

	char c, prev = 0;

	while (std::cin >> c)      /* (EOF maps to 0) */
	{
		if (c == '/' && prev == '*')
			return;
		prev = c;
	}

    yyerror("unterminated comment");
}
