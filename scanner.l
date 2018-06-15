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

int yycol = 1;
int yyrow = 1;

extern void yyerror(const char *);  /* prints grammar violation message */

#define SAVE_TOKEN yylval.string = new std::string(yytext)
#define TOKEN(t) ( yylval.token = t)

static void comment(void);
void count_col(void);
void count_row(void);

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
"/*"                                { count_col(); comment(); }
"//".*                              { count_row(); /* consume //-comment */ }

"auto"                              { count_col(); return TOKEN(AUTO); }
"break"                             { count_col(); return TOKEN(BREAK); }
"case"                              { count_col(); return TOKEN(CASE); }
"char"                              { count_col(); SAVE_TOKEN; return (CHAR); }
"const"                             { count_col(); SAVE_TOKEN; return (CONST); }
"continue"                          { count_col(); return TOKEN(CONTINUE); }
"default"                           { count_col(); return TOKEN(DEFAULT); }
"do"                                { count_col(); return TOKEN(DO); }
"double"                            { count_col(); SAVE_TOKEN; return (DOUBLE); }
"else"                              { count_col(); return TOKEN(ELSE); }
"enum"                              { count_col(); return TOKEN(ENUM); }
"extern"                            { count_col(); SAVE_TOKEN; return (EXTERN); }
"float"                             { count_col(); SAVE_TOKEN; return(FLOAT); }
"for"                               { count_col(); return TOKEN(FOR); }
"goto"                              { count_col(); return TOKEN(GOTO); }
"if"                                { count_col(); return TOKEN(IF); }
"inline"                            { count_col(); SAVE_TOKEN; return (INLINE); }
"int"                               { count_col(); SAVE_TOKEN; return (INT); }
"long"                              { count_col(); SAVE_TOKEN; return (LONG); }
"register"                          { count_col(); SAVE_TOKEN; return (REGISTER); }
"restrict"                          { count_col(); SAVE_TOKEN; return (RESTRICT); }
"return"                            { count_col(); return TOKEN(RETURN); }
"short"                             { count_col(); SAVE_TOKEN; return (SHORT); }
"signed"                            { count_col(); SAVE_TOKEN; return (SIGNED); }
"sizeof"                            { count_col(); return TOKEN(SIZEOF); }
"static"                            { count_col(); SAVE_TOKEN; return(STATIC); }
"struct"                            { count_col(); return TOKEN(STRUCT); }
"switch"                            { count_col(); return TOKEN(SWITCH); }
"typedef"                           { count_col(); SAVE_TOKEN; return (TYPEDEF); }
"union"                             { count_col(); return TOKEN(UNION); }
"unsigned"                          { count_col(); SAVE_TOKEN; return (UNSIGNED); }
"void"                              { count_col(); SAVE_TOKEN; return (VOID); }
"volatile"                          { count_col(); return TOKEN(VOLATILE); }
"while"                             { count_col(); return TOKEN(WHILE); }
"_Alignas"                          { count_col(); SAVE_TOKEN; return (ALIGNAS); }
"_Alignof"                          { count_col(); SAVE_TOKEN; return (ALIGNOF); }
"_Atomic"                           { count_col(); SAVE_TOKEN; return (ATOMIC); }
"_Bool"                             { count_col(); SAVE_TOKEN; return (BOOL); }
"_Complex"                          { count_col(); SAVE_TOKEN; return (COMPLEX); }
"_Generic"                          { count_col(); SAVE_TOKEN; return (GENERIC); }
"_Imaginary"                        { count_col(); SAVE_TOKEN; return (IMAGINARY); }
"_Noreturn"                         { count_col(); SAVE_TOKEN; return (NORETURN); }
"_Static_assert"                    { count_col(); SAVE_TOKEN; return (STATIC_ASSERT); }
"_Thread_local"                     { count_col(); SAVE_TOKEN; return (THREAD_LOCAL); }
"__func__"                          { count_col(); SAVE_TOKEN; return (FUNC_NAME); }

{L}{A}*                             { count_col(); SAVE_TOKEN; return (IDENTIFIER); /* Identifier */ }

{HP}{H}+{IS}?                       { count_col(); SAVE_TOKEN; return (I_CONSTANT); /* Integer */ }
{NZ}{D}*{IS}?                       { count_col(); SAVE_TOKEN; return (I_CONSTANT); /* Integer */ }
"0"{O}*{IS}?                        { count_col(); SAVE_TOKEN; return (I_CONSTANT); /* Integer */ }
{CP}?"'"([^'\\\n]|{ES})+"'"         { count_col(); SAVE_TOKEN; return (I_CONSTANT); /* Integer */ }

{D}+{E}{FS}?                        { count_col(); SAVE_TOKEN; return (F_CONSTANT); /* Floating Point */ }
{D}*"."{D}+{E}?{FS}?                { count_col(); SAVE_TOKEN; return (F_CONSTANT); /* Floating Point */ }
{D}+"."{E}?{FS}?                    { count_col(); SAVE_TOKEN; return (F_CONSTANT); /* Floating Point */ }
{HP}{H}+{P}{FS}?                    { count_col(); SAVE_TOKEN; return (F_CONSTANT); /* Floating Point */ }
{HP}{H}*"."{H}+{P}{FS}?             { count_col(); SAVE_TOKEN; return (F_CONSTANT); /* Floating Point */ }
{HP}{H}+"."{P}{FS}?                 { count_col(); SAVE_TOKEN; return (F_CONSTANT); /* Floating Point */ }

({SP}?\"([^"\\\n]|{ES})*\"{WS}*)+   { count_col(); SAVE_TOKEN; return (STRING_LITERAL); /* String Literal */ }

"..."                               { count_col(); return TOKEN(ELLIPSIS); }
">>="                               { count_col(); return TOKEN(RIGHT_ASSIGN); }
"<<="                               { count_col(); return TOKEN(LEFT_ASSIGN); }
"+="                                { count_col(); return TOKEN(ADD_ASSIGN); }
"-="                                { count_col(); return TOKEN(SUB_ASSIGN); }
"*="                                { count_col(); return TOKEN(MUL_ASSIGN); }
"/="                                { count_col(); return TOKEN(DIV_ASSIGN); }
"%="                                { count_col(); return TOKEN(MOD_ASSIGN); }
"&="                                { count_col(); return TOKEN(AND_ASSIGN); }
"^="                                { count_col(); return TOKEN(XOR_ASSIGN); }
"|="                                { count_col(); return TOKEN(OR_ASSIGN); }
">>"                                { count_col(); return TOKEN(RIGHT_OP); }
"<<"                                { count_col(); return TOKEN(LEFT_OP); }
"++"                                { count_col(); return TOKEN(INC_OP); }
"--"                                { count_col(); return TOKEN(DEC_OP); }
"->"                                { count_col(); return TOKEN(PTR_OP); }
"&&"                                { count_col(); return TOKEN(AND_OP); }
"||"                                { count_col(); return TOKEN(OR_OP); }
"<="                                { count_col(); return TOKEN(LE_OP); }
">="                                { count_col(); return TOKEN(GE_OP); }
"=="                                { count_col(); return TOKEN(EQ_OP); }
"!="                                { count_col(); return TOKEN(NE_OP); }
";"                                 { count_col(); return ';'; }
("{"|"<%")                          { count_col(); return '{'; }
("}"|"%>")                          { count_col(); return '}'; }
","                                 { count_col(); return ','; }
":"                                 { count_col(); return ':'; }
"="                                 { count_col(); return '='; }
"("                                 { count_col(); return '('; }
")"                                 { count_col(); return ')'; }
("["|"<:")                          { count_col(); return '['; }
("]"|":>")                          { count_col(); return ']'; }
"."                                 { count_col(); return '.'; }
"&"                                 { count_col(); return TOKEN(BIT_AND_OP); }
"!"                                 { count_col(); return '!'; }
"~"                                 { count_col(); return '~'; }
"-"                                 { count_col(); return TOKEN(SUB_OP); }
"+"                                 { count_col(); return TOKEN(ADD_OP); }
"*"                                 { count_col(); return TOKEN(MUL_OP); }
"/"                                 { count_col(); return TOKEN(DIV_OP); }
"%"                                 { count_col(); return TOKEN(MOD_OP); }
"<"                                 { count_col(); return TOKEN(LT_OP); }
">"                                 { count_col(); return TOKEN(GT_OP); }
"^"                                 { count_col(); return TOKEN(BIT_XOR_OP); }
"|"                                 { count_col(); return TOKEN(BIT_OR_OP); }
"?"                                 { count_col(); return '?'; }

[ \t\v\f]+                          { count_col(); /* whitespace separates tokens */ }
"\n"                                { count_row(); }
.                                   { /* discard bad characters */ }

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
        {
            count_col();
            return;
        }
		prev = c;
		if (c == '\n')
		{
		    count_row();
		}
		count_col();
	}

    yyerror("unterminated comment");
}

void count_col(void)
{
    int i;

    for (i = 0; yytext[i] != '\0'; i++)
    {
        if (yytext[i] == '\t')
        {
            yycol += 8 - (yycol % 8);
        }
        else
        {
            yycol++;
        }
    }
}

void count_row(void)
{
    yycol = 1;
    yyrow++;
}
