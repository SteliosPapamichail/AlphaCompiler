/* code */
%{
#if defined(WIN32)
#define YY_NO_UNISTD_H
static int isatty (int i) {return 0;}
#elif defined(_WIN32_WCE)
#define YY_NO_UNISTD_H
static int isatty (void *i) {return 0;}
#endif
#include "lexer.h"

// vars
unsigned int counter = 1u;
// comment-related
unsigned int commentnest = 0u;
unsigned int comm_starting_line = 0u;
// string-related
string str_buf = "";    
unsigned int str_starting_line = 0u;

%}

/* Flex Options */
/* Read only 1 File */
%option noyywrap
%option yylineno

/* Flex macros */
id                  [a-zA-Z][a-zA-Z_0-9]*
integer             [0-9]+
real                [0-9]*\.[0-9]+
LETTER              [a-zA-Z]
DIGIT               [0-9]
ALPHANUM            ({LETTER}|{DIGIT})
ALPHANUM_           ({ALPHANUM}|_)
inline_comment      \/\/.*
%x MULTICOM
%x STRINGS
%%

 /* RULES BLOCK */
\n
       
"if"		{print_token(KEYWORD,token_node); return IF;}
"else"		{print_token(KEYWORD,token_node); return ELSE;}
"while"		{print_token(KEYWORD,token_node); return WHILE;}
"for"		{print_token(KEYWORD,token_node); return FOR;}
"function"	{print_token(KEYWORD,token_node); return FUNCTION;}
"return"	{print_token(KEYWORD,token_node); return RETURN;}
"break"		{print_token(KEYWORD,token_node); return BREAK;}
"continue"	{print_token(KEYWORD,token_node); return CONTINUE;}
"and"		{print_token(KEYWORD,token_node); return AND;}
"not"		{print_token(KEYWORD,token_node); return NOT;}
"or"		{print_token(KEYWORD,token_node); return OR;}
"local"		{print_token(KEYWORD,token_node); return LOCAL;}
"true"		{print_token(KEYWORD,token_node); return TRUE;}
"false"		{print_token(KEYWORD,token_node); return FALSE;}
"nil"		{print_token(KEYWORD,token_node); return NIL;}

"++"        {print_token(OPERATOR,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return PLUSPLUS;}
"--"        {print_token(OPERATOR,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return MINMIN;}
"-"         {print_token(OPERATOR,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return MIN;}
"*"         {print_token(OPERATOR,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return MUL;}
"/"         {print_token(OPERATOR,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return DIV;}
"%"         {print_token(OPERATOR,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return MOD;}
"=="        {print_token(OPERATOR,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return EQUAL;}
"!="        {print_token(OPERATOR,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return NEQUAL;}
"+"         {print_token(OPERATOR,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return PLUS;}
"="         {print_token(OPERATOR,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return ASSIGN;}
">"         {print_token(OPERATOR,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return GRTR;}
"<"         {print_token(OPERATOR,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return LESS;}
">="        {print_token(OPERATOR,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return GRTREQ;}
"<="        {print_token(OPERATOR,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return LESSEQ;}

"{"         {print_token(PUNCTUATION,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return CBRACK_L;}
"}"         {print_token(PUNCTUATION,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return CBRACK_R;}
"("         {print_token(PUNCTUATION,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return PAR_L;}
")"         {print_token(PUNCTUATION,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return PAR_R;}
"["         {print_token(PUNCTUATION,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return BRACK_L;}
"]"         {print_token(PUNCTUATION,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return BRACK_R;}
";"         {print_token(PUNCTUATION,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return SEMICOL;}
","         {print_token(PUNCTUATION,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return COMMA;}
":"         {print_token(PUNCTUATION,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return COL;}
"::"        {print_token(PUNCTUATION,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return COLCOL;}
"."         {print_token(PUNCTUATION,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return DOT;}
".."        {print_token(PUNCTUATION,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return DOTDOT;}

"/*"       { BEGIN(MULTICOM); comm_starting_line = yylineno; print_token(MULTILINE_COMMENT,token_node);}

{inline_comment} {print_token(COMMENT,token_node);}

{id}             {print_token(IDENTIFIER,token_node); string *test = new string; *test = yytext; (yylval.strval) = test; return ID;}

{integer}        {print_token(INT_CONST,token_node); yylval.intval = stoi(yytext); return INTCONST;}

{real}           {print_token(REAL_CONST,token_node); yylval.realval = stof(yytext); return REALCONST;}

\"              {
                    str_buf = "";
                    str_starting_line = yylineno;
                    BEGIN(STRINGS);
                }
 
<STRINGS>{
    \"          { print_token(STRING_CONST,token_node); string *test = new string; *test = str_buf; (yylval.strval) = test; BEGIN(INITIAL); return STRCONST;}
    \n                                        {str_buf.append("\n");}
    \\n                                       {str_buf.append("\n");}
    \\f                                       {str_buf.append("\f");}
    \\t                                       {str_buf.append("\t");}
    \\r                                       {str_buf.append("\r");}
    \\b                                       {str_buf.append("\b");}
    \\v                                       {str_buf.append("\v");}
    \\\\                                      {str_buf.append("\\");}
    \\\"                                      {str_buf.append("\"");}
    \\\n                                      {}
    \\{ALPHANUM_}?                            {fprintf(stderr, ANSI_COLOR_YELLOW "[WARNING] at line %d: Undefined escape character '%s'\n" ANSI_COLOR_RESET, yylineno, yytext); str_buf.append(yytext);}
    [^\\\n\"]+                                {str_buf.append(yytext);}
    <<EOF>>                                   {fprintf(stderr, ANSI_COLOR_RED "[ERROR] at line %d: Strings must end with a closing \"\n" ANSI_COLOR_RESET,yylineno); str_buf = ""; exit(-1);}
}

<MULTICOM>{
    "/*"        {
                    ++commentnest;
                }
    "*/"        { 
                    if (commentnest > 0) {
                        --commentnest;
                        print_token(NESTED_COMMENT,token_node);
                    }
                    else {
                        BEGIN(INITIAL);
                        //return MULTILINE_COMMENT;
                    }
                }
    \n          {}
    <<EOF>>     {
                        fprintf(stderr, ANSI_COLOR_RED "[ERROR] at line %d: No ending clause for multiline comment\n!" ANSI_COLOR_RESET,yylineno);
                        exit(-1);
                }
    .           {}
}

[\r \t\v]
.              {fprintf(stderr, ANSI_COLOR_RED "[ERROR] at line %d: Undefined token '%s'\n" ANSI_COLOR_RESET, yylineno, yytext); return UNKNOWN;}   
<<EOF>>        {return EOF;}

%%

void print_token(enum TOKEN_T_ENUM tokentype, alpha_token_t tok) {
    tok = new alpha_token;
    tok->token_number = counter++;
    tok->line = yylineno;
    tok->content = yytext; 
    tok->next = NULL;
    switch(tokentype){
        case UNKNOWN:
            printf("\nUNKNOWN\n");
            break;
        case INT_CONST:
            tok->token_type = INT_CONST;
            break;
        case STRING_CONST:
            tok->line = str_starting_line;
            tok->token_type = STRING_CONST;
            tok->content = str_buf;
            break;
        case IDENTIFIER:
            tok->token_type = IDENTIFIER;
            break;
        case KEYWORD:
	        tok->token_type = KEYWORD;
            break;
        case REAL_CONST:
	        tok->token_type = REAL_CONST;
            break;
        case OPERATOR:
	        tok->token_type = OPERATOR;
            break;
        case PUNCTUATION:
	        tok->token_type = PUNCTUATION;
            break;
        case MULTILINE_COMMENT:
            tok->line = comm_starting_line; 
	        tok->token_type = MULTILINE_COMMENT;
            tok->content = "";
            break;
        case NESTED_COMMENT:
	        tok->token_type = NESTED_COMMENT;
            tok->content = "";
            break;
        default:
	        tok->token_type = COMMENT;
            tok->content = "";
    }
    //cout << "line=" << tok->line << ":  #" << tok->token_number << "\t  \"" << tok->content << "\"\t\t" << TOKEN_T_STRING[tok->token_type] << endl;
    
    // connect the new node to the list
    alpha_token_t ptr = head;
    if(!head) {
        head = tok;
    } else {
        while(ptr->next) ptr = ptr->next;
        ptr->next = tok;
    }
}