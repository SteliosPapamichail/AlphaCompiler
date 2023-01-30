%{
#include <iostream>
#include <unistd.h>
#include <string>
#include <algorithm>
#include <map>
#include <cstring>
#include <cmath>
using namespace std;
#include "parser.h"

#define ANSI_COLOR_RED     "\x1b[31m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_RESET   "\x1b[0m"

SymTable_T symtab;
int scope = 0;
int numOfAnon = 0;
bool isInsideLoop = false;
bool isMemberOfFunc = false;
bool islocalid = false;
enum BlockT {Loop,Func,Block};
vector<BlockT> stack;
// used for temporarily storing function args
vector<string> func_args;
extern int yylineno;
extern bool isHidingBindings;
// func declerations
extern bool isLibFunc(string);
extern int isFunc(string id,int scope);
int yyerror(alpha_token_t node, string msg);

// quads
unsigned int program_var_scope_offset = 0;
unsigned int function_local_scope_offset = 0;
unsigned int formal_arg_scope_offset = 0;
vector<quad> quads;
// *** Helper variables ***
unsigned int scopeSpaceCounter = 1;
unsigned int programVarOffset = 0;
unsigned int functionLocalOffset = 0;
unsigned int formalArgOffset = 0;
//
vector<int> break_index;
vector<int> continue_index;
vector<int> return_index;
vector<int> funcOffsetStack;
%}

%code requires {
    #include "../settings.h"
    #include "../SymTab/symtable.h"
    #include <string>
    #include "../utils/parser-utils.hpp"
}

%param { alpha_token_t token_node }
%code provides {
    #define YY_DECL \
        int yylex(alpha_token_t token_node)
    YY_DECL;
}

%union{
    int intval;
    double realval;
    bool boolval;
    std::string *strval;
    struct expr* expr;
    tup* tpl;
    struct forLoop *forLoopval;
    struct method_call *method_call ;
}

%token <intval> INTCONST
%token <realval> REALCONST
%token <strval> STRCONST
%token <strval> IF ELSE WHILE FOR FUNCTION RETURN BREAK CONTINUE
%token <strval> AND NOT OR LOCAL NIL ID
%token <boolval> TRUE FALSE
%token <strval> PAR_L PAR_R BRACK_L BRACK_R DOT DOTDOT PLUS PLUSPLUS MIN MINMIN MINUNARY
%token <strval> MUL DIV MOD GRTR GRTREQ LESS LESSEQ ASSIGN EQUAL NEQUAL
%token <strval> CBRACK_L CBRACK_R SEMICOL COMMA COL COLCOL
%type<expr>  expr stmt whilestmt forstmt returnstmt block funcdef funcprefix assignexpr term
%type<tpl> indexedelem indexed
%type<expr>  elist lvalue primary objectdef const member idlist call
%type<method_call> callsuffix normcall  methodcall
%type<intval> ifprefix elseprefix ifstmt funcbody funcargs
%type<intval> whilestart whilecond N M
%type<forLoopval> forprefix

%right ASSIGN
%left OR
%left AND
%nonassoc EQUAL NEQUAL
%nonassoc GRTR GRTREQ LESS LESSEQ
%left PLUS MIN
%left MUL DIV MOD
%right NOT PLUSPLUS MINMIN MINUNARY
%left DOT DOTDOT
%left BRACK_L BRACK_R
%left PAR_L PAR_R
%start program
/*ALPHA GRAMMAR*/
%%
program:                        stmtlist;

stmtlist:                       stmtlist stmt
                            |   %empty
                            ;
stmt:                           expr SEMICOL    {short_circuit($1,scope,true); resettemp();}
                            |   ifstmt {resettemp();}
                            |   whilestmt {resettemp();}
                            |   forstmt {resettemp();}
                            |   returnstmt                      {   bool ok=false;
                                                                    for (int i=stack.size()-1; i>=0; i--)
                                                                        if (stack.at(i) == Func) ok = true;
                                                                    if (ok==false) {
                                                                        yyerror(token_node,"Use of \"return\" while not in a function");
                                                                        YYABORT;
                                                                    }
                                                                    resettemp();
                                                                }
                            |   BREAK SEMICOL                   {   bool ok=false;
                                                                    for (int i=stack.size()-1; i>=0; i--)
                                                                        if (stack.at(i) == Loop) ok = true;
                                                                    if (ok==false) {
                                                                        yyerror(token_node,"Use of \"break\" while not in a loop");
                                                                        YYABORT;
                                                                    }
                                                                    emit(jump,NULL,NULL,NULL,0,yylineno);
                                                                    break_index.push_back(nextquadlabel()-1);
                                                                    resettemp();
                                                                }
                            |   CONTINUE SEMICOL                {   bool ok=false;
                                                                    for (int i=stack.size()-1; i>=0; i--)
                                                                        if (stack.at(i) == Loop) ok = true;
                                                                    if (ok==false) {
                                                                        yyerror(token_node,"Use of \"continue\" while not in a loop");
                                                                        YYABORT;
                                                                    }
                                                                    emit(jump,NULL,NULL,NULL,0,yylineno);
                                                                    continue_index.push_back(nextquadlabel()-1);
                                                                    resettemp();
                                                                }
                            |   block {
                                        $$=$1;
                                        resettemp();
                                      }
                            |   funcdef {resettemp();}
                            |   SEMICOL {resettemp();}
                            ;
expr:                           assignexpr      {$$=$1;}
                            |   expr PLUS expr
                                {
                                    binding *b = nullptr;
                                    if (istempexpr($1)) b = $1->sym;
                                    else if (istempexpr($3)) b = $3->sym;
                                    bool isExpr1Arithm = check_arith($1);
                                    bool isExpr2Arithm = check_arith($3);
                                    if(isNonArithmeticConstValue($1) || isNonArithmeticConstValue($3)) {
                                        yyerror(token_node, "Invalid addition operands!");
                                        YYABORT;
                                    } else {
                                        $$ = newexpr(arithmetic_e);
                                        if (b!=nullptr) $$->sym = b;
                                        else $$->sym = newtemp(scope);
                                        if(isExpr1Arithm && isExpr2Arithm) $$->numConst = $1->numConst + $3->numConst;
                                        emit(add, $1, $3, $$, nextquadlabel(), yylineno);
                                    }
                                }
                            |   expr MIN expr
                                {
                                    binding *b = nullptr;
                                    if (istempexpr($1)) b = $1->sym;
                                    else if (istempexpr($3)) b = $3->sym;
                                    bool isExpr1Arithm = check_arith($1);
                                    bool isExpr2Arithm = check_arith($3);
                                    if(isNonArithmeticConstValue($1) || isNonArithmeticConstValue($3)) {
                                        yyerror(token_node, "Invalid subtraction operands!");
                                        YYABORT;
                                    } else {
                                        $$ = newexpr(arithmetic_e);
                                        if (b!=nullptr) $$->sym = b;
                                        else $$->sym = newtemp(scope);
                                        if(isExpr1Arithm && isExpr2Arithm) $$->numConst = $1->numConst - $3->numConst;
                                        emit(sub, $1, $3, $$, nextquadlabel(), yylineno);
                                    }
                                }
                            |   expr MUL expr
                                {
                                    binding *b = nullptr;
                                    if (istempexpr($1)) b = $1->sym;
                                    else if (istempexpr($3)) b = $3->sym;
                                    bool isExpr1Arithm = check_arith($1);
                                    bool isExpr2Arithm = check_arith($3);
                                    if(isNonArithmeticConstValue($1) || isNonArithmeticConstValue($3)) {
                                        yyerror(token_node, "Invalid multiplication operands!");
                                        YYABORT;
                                    } else {
                                        $$ = newexpr(arithmetic_e);
                                        if (b!=nullptr) $$->sym = b;
                                        else $$->sym = newtemp(scope);
                                        if(isExpr1Arithm && isExpr2Arithm) $$->numConst = $1->numConst * $3->numConst;
                                        emit(mul, $1, $3, $$, nextquadlabel(), yylineno);
                                    }
                                }
                            |   expr DIV expr
                                {
                                    binding *b = nullptr;
                                    if (istempexpr($1)) b = $1->sym;
                                    else if (istempexpr($3)) b = $3->sym;
                                    bool isExpr1Arithm = check_arith($1);
                                    bool isExpr2Arithm = check_arith($3);
                                    if(isNonArithmeticConstValue($1) || isNonArithmeticConstValue($3)) {
                                        yyerror(token_node, "Invalid division operands!");
                                        YYABORT;
                                    } else {
                                        if($3->type == const_num  && $3->numConst == 0) {
                                            yyerror(token_node, "division by 0!");
                                            YYABORT;
                                        } else {
                                            $$ = newexpr(arithmetic_e);
                                            if (b!=nullptr) $$->sym = b;
                                            else $$->sym = newtemp(scope);
                                            if(isExpr1Arithm && isExpr2Arithm) $$->numConst = $1->numConst / $3->numConst;
                                            emit(div_op, $1, $3, $$, nextquadlabel(), yylineno);
                                        }
                                    }
                                }
                            |   expr MOD expr
                                {
                                    binding *b = nullptr;
                                    if (istempexpr($1)) b = $1->sym;
                                    else if (istempexpr($3)) b = $3->sym;
                                    bool isExpr1Arithm = check_arith($1);
                                    bool isExpr2Arithm = check_arith($3);
                                    if(isNonArithmeticConstValue($1) || isNonArithmeticConstValue($3)) {
                                        yyerror(token_node, "Invalid modulus operands!");
                                        YYABORT;
                                    } else {
                                        if($3->type == const_num  && $3->numConst == 0) {
                                            yyerror(token_node, "division by 0!");
                                            YYABORT;
                                        } else {
                                            $$ = newexpr(arithmetic_e);
                                            if (b!=nullptr) $$->sym = b;
                                            else $$->sym = newtemp(scope);
                                            if(isExpr1Arithm && isExpr2Arithm) $$->numConst = fmod($1->numConst,$3->numConst);
                                            emit(mod_op, $1, $3, $$, nextquadlabel(), yylineno);
                                        }
                                    }
                                }

                            |   expr GRTR expr
                                {
                                    bool isExpr1Arithm = check_arith($1);
                                    bool isExpr2Arithm = check_arith($3);
                                    if(!isExpr1Arithm || !isExpr2Arithm)
                                    {
                                        if(isNonArithmeticConstValue($1) || isNonArithmeticConstValue($3)) {
                                            yyerror(token_node, "Invalid relational operands!");
                                            YYABORT;
                                        } else {
                                            $$ = newexpr(bool_e);
                                            $$->sym = newtemp(scope);
                                            emit(if_greater, $1, $3, NULL, 0, yylineno);
                                            $$->truelist.push_back(nextquadlabel()-1);
                                            emit(jump, NULL,NULL,NULL, 0, yylineno);
                                            $$->falselist.push_back(nextquadlabel()-1);

                                        }
                                    } else {
                                        $$ = newConstBoolExpr($1->numConst > $3->numConst);
                                    }
                                }
                            |   expr GRTREQ expr
                                {
                                    bool isExpr1Arithm = check_arith($1);
                                    bool isExpr2Arithm = check_arith($3);
                                    if(!isExpr1Arithm || !isExpr2Arithm)
                                    {
                                        if(isNonArithmeticConstValue($1) || isNonArithmeticConstValue($3)) {
                                            yyerror(token_node, "Invalid relational operands!");
                                            YYABORT;
                                        } else {
                                            $$ = newexpr(bool_e);
                                            $$->sym = newtemp(scope);
                                            emit(if_greatereq, $1, $3, NULL, nextquadlabel() + 4, yylineno);
                                            $$->truelist.push_back(nextquadlabel()-1);
                                            emit(assign, newConstBoolExpr(false), NULL, $$, nextquadlabel(), yylineno);
                                            $$->falselist.push_back(nextquadlabel()-1);
                                        }
                                    } else {
                                        $$ = newConstBoolExpr($1->numConst >= $3->numConst);
                                    }
                                }
                            |   expr LESS expr
                                {
                                    bool isExpr1Arithm = check_arith($1);
                                    bool isExpr2Arithm = check_arith($3);
                                    if(!isExpr1Arithm || !isExpr2Arithm)
                                    {
                                        if(isNonArithmeticConstValue($1) || isNonArithmeticConstValue($3)) {
                                            yyerror(token_node, "Invalid relational operands!");
                                            YYABORT;
                                        } else {
                                            $$ = newexpr(bool_e);
                                            $$->sym = newtemp(scope);
                                            emit(if_less, $1, $3, NULL, nextquadlabel() + 4, yylineno);
                                            $$->truelist.push_back(nextquadlabel()-1);
                                            emit(jump, NULL,NULL,NULL, nextquadlabel() + 3, yylineno);
                                            $$->falselist.push_back(nextquadlabel()-1);
                                        }
                                    } else {
                                        $$ = newConstBoolExpr($1->numConst < $3->numConst);
                                    }
                                }
                            |   expr LESSEQ expr
                                {
                                    bool isExpr1Arithm = check_arith($1);
                                    bool isExpr2Arithm = check_arith($3);
                                    if(!isExpr1Arithm || !isExpr2Arithm)
                                    {
                                        if(isNonArithmeticConstValue($1) || isNonArithmeticConstValue($3)) {
                                            yyerror(token_node, "Invalid relational operands!");
                                            YYABORT;
                                        } else {
                                            $$ = newexpr(bool_e);
                                            $$->sym = newtemp(scope);
                                            emit(if_lesseq, $1, $3, NULL,0, yylineno);
                                            $$->truelist.push_back(nextquadlabel()-1);
                                            emit(jump, NULL,NULL,NULL, nextquadlabel() + 3, yylineno);
                                            $$->falselist.push_back(nextquadlabel()-1);
                                        }
                                    } else {
                                        $$ = newConstBoolExpr($1->numConst <= $3->numConst);
                                    }
                                }
                            |   expr EQUAL {
                                            if($1->type == bool_e && $1->flag == true){
                                                $1->sym = newtemp(scope);
                                                patchlist($1->truelist,nextquadlabel());
                                                emit(assign,newConstBoolExpr(false),NULL,$1,nextquadlabel(),yylineno);
                                                emit(jump,NULL,NULL,NULL,nextquadlabel()+2,yylineno);
                                                patchlist($1->falselist,nextquadlabel());
                                                emit(assign,newConstBoolExpr(false),NULL,$1,nextquadlabel(),yylineno);
                                            }
                                           } expr
                                {   $$ = newexpr(bool_e);
                                    if($4->type == bool_e && $4->flag==true){
                                        $4->sym = newtemp(scope);
                                        patchlist($4->truelist,nextquadlabel());
                                        emit(assign,newConstBoolExpr(true),NULL,$4,nextquadlabel(),yylineno);
                                        emit(jump,NULL,NULL,NULL,nextquadlabel()+2,yylineno);
                                        patchlist($4->falselist,nextquadlabel());
                                        emit(assign,newConstBoolExpr(false),NULL,$4,nextquadlabel(),yylineno);
                                    }
                                    $$->truelist.push_back(nextquadlabel());
                                    $$->falselist.push_back(nextquadlabel()+1);
                                    emit(if_eq,$1,$4,NULL,nextquadlabel(),yylineno);
                                    emit(jump,NULL,NULL,NULL,nextquadlabel(),yylineno);
                                }
                            |   expr NEQUAL {
                                                if($1->type == bool_e && $1->flag==true){
                                                    $1->sym = newtemp(scope);
                                                    patchlist($1->truelist,nextquadlabel());
                                                    emit(assign,newConstBoolExpr(true),NULL,$1,nextquadlabel(),yylineno);
                                                    emit(jump,NULL,NULL,NULL,nextquadlabel()+2,yylineno);
                                                    patchlist($1->falselist,nextquadlabel());
                                                    emit(assign,newConstBoolExpr(false),NULL,$1,nextquadlabel(),yylineno);
                                                }
                                            } expr
                                {   $$ = newexpr(bool_e);
                                    if($4->type == bool_e && $4->flag==true){
                                        $4->sym = newtemp(scope);
                                        patchlist($4->truelist,nextquadlabel());
                                        emit(assign,newConstBoolExpr(true),NULL,$4,nextquadlabel(),yylineno);
                                        emit(jump,NULL,NULL,NULL,nextquadlabel()+2,yylineno);
                                        patchlist($4->falselist,nextquadlabel());
                                        emit(assign,newConstBoolExpr(false),NULL,$4,nextquadlabel(),yylineno);
                                    }
                                    $$->truelist.push_back(nextquadlabel());
                                    $$->falselist.push_back(nextquadlabel()+1);
                                    emit(if_noteq,$1,$4,NULL,nextquadlabel(),yylineno);
                                    emit(jump,NULL,NULL,NULL,nextquadlabel(),yylineno);
                                }
                            |   expr AND{
                                    if($1->type != bool_e){
                                        $1->truelist.push_back(nextquadlabel());
                                        $1->falselist.push_back(nextquadlabel()+1);
                                        emit(if_eq,$1,newConstBoolExpr(true),NULL,nextquadlabel(),yylineno);
                                        emit(jump,NULL,NULL,NULL,nextquadlabel(),yylineno);
                                        patchlist($1->truelist,nextquadlabel()+1);
                                    }
                                } M expr
                                {   $$ = newexpr(bool_e);
                                    if($5->type != bool_e){
                                        $5->truelist.push_back(nextquadlabel());
                                        $5->falselist.push_back(nextquadlabel()+1);
                                        emit(if_eq,$5,newConstBoolExpr(true),NULL,nextquadlabel(),yylineno);
                                        emit(jump,NULL,NULL,NULL,nextquadlabel(),yylineno);
                                    }
                                    if($1->type == bool_e){
                                        patchlist($1->truelist,$4+1);    //patch gia ta if_eq
                                    }
                                    $$->truelist = $5->truelist;
                                    $$->falselist = mergelists($1->falselist,$5->falselist);
                                }
                            |   expr OR {
                                    if($1->type != bool_e){
                                        $1->truelist.push_back(nextquadlabel());
                                        $1->falselist.push_back(nextquadlabel()+1);
                                        emit(if_eq,$1,newConstBoolExpr(true),NULL,nextquadlabel(),yylineno);
                                        emit(jump,NULL,NULL,NULL,nextquadlabel(),yylineno);
                                        patchlist($1->falselist,nextquadlabel()+1);
                                    }
                                } M expr
                                {   $$ = newexpr(bool_e);
                                    if($5->type != bool_e){
                                        $5->truelist.push_back(nextquadlabel());
                                        $5->falselist.push_back(nextquadlabel()+1);
                                        emit(if_eq,$5,newConstBoolExpr(true),NULL,nextquadlabel(),yylineno);
                                        emit(jump,NULL,NULL,NULL,nextquadlabel(),yylineno);
                                    }

                                    if($1->type == bool_e){
                                        patchlist($1->falselist,$4+1);  //patch ta jump twn if_eq
                                        }
                                    $$->truelist = mergelists($1->truelist,$5->truelist);
                                    $$->falselist = $5->falselist;
                                }

                            |   term {$$ = $1;}
                            ;

term:                           PAR_L expr PAR_R { $$ = $2; }
                            |   MIN expr
                                {
                                    if(!check_arith($2) && isNonArithmeticConstValue($2)) {
                                        string msg = "Illegal expr used with unary operator \'-\' on line " + to_string(yylineno) + "!";
                                        yyerror(token_node, msg);
                                        YYABORT;
                                    } else {
                                        expr* tmp = newexpr(arithmetic_e);
                                        tmp->sym = istempexpr($2) ? $2->sym : newtemp(scope);
                                        tmp->numConst = -$2->numConst;
                                        emit(uminus, $2, NULL, tmp, nextquadlabel(), yylineno);
                                        $$ = tmp;
                                    }
                                } %prec MINUNARY
                            |   NOT expr
                                {
                                    $$ = newexpr(bool_e);
                                    $$->sym = $2->sym;
                                    $$->flag = true;
                                    if($2->type != bool_e){
                                        emit(if_eq,$2,newConstBoolExpr(true),NULL,nextquadlabel(),yylineno);
                                        $$->falselist.push_back(nextquadlabel()-1);
                                        emit(jump,NULL,NULL,NULL,nextquadlabel(),yylineno);
                                        $$->truelist.push_back(nextquadlabel()-1);
                                    }else{
                                        $$->truelist = $2->falselist;
                                        $$->falselist = $2->truelist;
                                    }
                                }
                            |   PLUSPLUS lvalue  {
                                                    if ( isFunc($2->sym->key,scope)) {
                                                        yyerror(token_node,"User function \"" + $2->sym->key + "\" is not lvalue!");
                                                        YYABORT;
                                                    }
                                                    else if(isLibFunc($2->sym->key)) {
                                                        yyerror(token_node,"Library function \"" + $2->sym->key + "\" is not lvalue!");
                                                        YYABORT;
                                                    }
                                                    else {
                                                        if(!check_arith($2) && isNonArithmeticConstValue($2)) {
                                                            yyerror(token_node, "Illegal operand type for \'++\' prefix operation!");
                                                            YYABORT;
                                                        }
                                                        else {
                                                            if($2->type == tableitem_e) {
                                                                $$ = emit_iftableitem($2, nextquadlabel(), yylineno, scope);
                                                                emit(add, $$, newConstNumberExpr(1), $$, nextquadlabel(), yylineno);
                                                                emit(tablesetelem, $2->index, $$, $2, nextquadlabel(), yylineno);
                                                            } else {
                                                                emit(add, $2, newConstNumberExpr(1), $2, nextquadlabel(),yylineno);
                                                                $$ = newexpr(arithmetic_e);
                                                                $$->sym = newtemp(scope);
                                                                emit(assign, $2, NULL, $$, nextquadlabel(), yylineno);
                                                            }
                                                        }
                                                    }
                                                 }
                            |   lvalue PLUSPLUS  {
                                                    if ( isFunc($1->sym->key,scope)) {
                                                        yyerror(token_node,"User function \"" + $1->sym->key + "\" is not lvalue!");
                                                        YYABORT;
                                                    }
                                                    else if(isLibFunc($1->sym->key)) {
                                                        yyerror(token_node,"Library function \"" + $1->sym->key + "\" is not lvalue!");
                                                        YYABORT;
                                                    }
                                                    if(!check_arith($1) && isNonArithmeticConstValue($1)) {
                                                        yyerror(token_node, "Illegal operand type for \'++\' postfix operation!");
                                                        YYABORT;
                                                    }
                                                    else {
                                                            $$ = newexpr(var);
                                                            $$->sym = newtemp(scope);
                                                            if($1->type == tableitem_e) {
                                                                expr* val = emit_iftableitem($1, nextquadlabel(), yylineno, scope);
                                                                emit(assign, val, NULL, $$, nextquadlabel(), yylineno);
                                                                emit(add, val, newConstNumberExpr(1), val, nextquadlabel(), yylineno);
                                                                emit(tablesetelem, $1->index, val, $1, nextquadlabel(), yylineno);
                                                            } else {
                                                                emit(assign, $1, NULL, $$, nextquadlabel(), yylineno);
                                                                emit(add, $1, newConstNumberExpr(1), $1, nextquadlabel(),yylineno);
                                                            }
                                                    }
                                                 }
                            |   MINMIN lvalue   {
                                                    if ( isFunc($2->sym->key,scope)) {
                                                        yyerror(token_node,"User function \"" + $2->sym->key + "\" is not lvalue!");
                                                        YYABORT;
                                                    }
                                                    else if(isLibFunc($2->sym->key)) {
                                                        yyerror(token_node,"Library function \"" + $2->sym->key + "\" is not lvalue!");
                                                        YYABORT;
                                                    }
                                                    else {
                                                        if(!check_arith($2) && isNonArithmeticConstValue($2)) {
                                                            yyerror(token_node, "Illegal operand type for \'--\' prefix operation!");
                                                            YYABORT;
                                                        }
                                                        else {
                                                            if($2->type == tableitem_e) {
                                                                $$ = emit_iftableitem($2, nextquadlabel(), yylineno, scope);
                                                                emit(sub, $$, newConstNumberExpr(1), $$, nextquadlabel(), yylineno);
                                                                emit(tablesetelem, $2->index, $$, $2, nextquadlabel(), yylineno);
                                                            } else {
                                                                emit(sub, $2, newConstNumberExpr(1), $2, nextquadlabel(),yylineno);
                                                                $$ = newexpr(arithmetic_e);
                                                                $$->sym = newtemp(scope);
                                                                emit(assign, $2, NULL, $$, nextquadlabel(), yylineno);
                                                            }
                                                        }
                                                    }
                                                }
                            |   lvalue MINMIN   {
                                                    if(!check_arith($1) && isNonArithmeticConstValue($1)) {
                                                        yyerror(token_node,"User function \"" + $1->sym->key + "\" is not lvalue!");
                                                        YYABORT;
                                                    }
                                                    else if(isLibFunc($1->sym->key)) {
                                                        yyerror(token_node,"Library function \"" + $1->sym->key + "\" is not lvalue!");
                                                        YYABORT;
                                                    }
                                                    if(!check_arith($1) && isNonArithmeticConstValue($1)) {
                                                        yyerror(token_node, "Illegal operand type for \'--\' postfix operation!");
                                                        YYABORT;
                                                    }
                                                    else {
                                                            $$ = newexpr(var);
                                                            $$->sym = newtemp(scope);
                                                            if($1->type == tableitem_e) {
                                                                expr* val = emit_iftableitem($1, nextquadlabel(), yylineno, scope);
                                                                emit(assign, val, NULL, $$, nextquadlabel(), yylineno);
                                                                emit(sub, val, newConstNumberExpr(1), val, nextquadlabel(), yylineno);
                                                                emit(tablesetelem, $1->index, val, $1, nextquadlabel(), yylineno);
                                                            } else {
                                                                emit(assign, $1, NULL, $$, nextquadlabel(), yylineno);
                                                                emit(sub, $1, newConstNumberExpr(1), $1, nextquadlabel(),yylineno);
                                                            }
                                                    }
                                                }
                            |   primary ASSIGN expr {yyerror(token_node, "Function \"" + $1->sym->key + "()\" is not lvalue"); YYABORT;}
                            |   primary { $$ = $1; }
                            ;
assignexpr:                     lvalue ASSIGN expr  {   if ( isMemberOfFunc )
                                                        {
                                                            isMemberOfFunc=false;
                                                        }
                                                        else{   if ( islocalid==true ){
                                                                    islocalid = false;
                                                                }else{
                                                                    if ( isLibFunc($1->sym->key) ) {
                                                                        yyerror(token_node,"Library function \"" + $1->sym->key + "\" is not lvalue!");
                                                                        YYABORT;
                                                                    }
                                                                    if (SymTable_lookup(symtab,$1->sym->key,scope,false) && isFunc($1->sym->key,scope)) {
                                                                        yyerror(token_node,"User function \"" + $1->sym->key + "\" is not lvalue!");
                                                                        YYABORT;
                                                                    }
                                                                }
                                                        }
                                                        short_circuit($3,scope,false);
                                                        if($1->type == tableitem_e)
                                                        {
                                                            // lvalue[index] = expr
                                                            emit(tablesetelem,$1->index,$3,$1,nextquadlabel(),yylineno);
                                                            $$ = emit_iftableitem($1,nextquadlabel(),yylineno, scope);
                                                            $$->type = assignment;
                                                        } else
                                                        {
                                                            emit(assign,$3,NULL,$1,nextquadlabel(),yylineno); //lval = expr;
                                                            $$ = newexpr(assignment);
                                                            $$->sym = newtemp(scope);
                                                            emit(assign, $1,NULL,$$,nextquadlabel(),yylineno);
                                                        }
                                                    }
                            ;

primary:                        lvalue { $$ = emit_iftableitem($1,nextquadlabel(),yylineno, scope); }
                            |   call
                            |   objectdef
                            |   PAR_L funcdef PAR_R {$$ = newexpr(user_func); $$ = $2; }
                            |   const {$$ = $1;}
                            ;

lvalue:                         ID                  {
                                                        if (!SymTable_lookup(symtab,*$1,scope,false)) {
                                                            if(isHidingBindings){
                                                                int lookup = 0;
                                                                for (int i=stack.size()-1; i>=0; i--){
                                                                    if (stack.at(i)!=Func) continue;
                                                                    SymTable_show(symtab,i);
                                                                    if ( SymTable_lookup(symtab,*$1,i,false) ) lookup++;
                                                                    SymTable_hide(symtab,i);
                                                                }
                                                                if(lookup!=0) {
                                                                    yyerror(token_node,"Cannot access variable \"" + *$1 + "\"");
                                                                    YYABORT;
                                                                }
                                                                else{
                                                                    SymbolType type;
                                                                    if (scope==0) type = GLOBAL_;
                                                                    else type = LOCAL_;

                                                                    binding* sym = SymTable_put(symtab,*$1,scope,type,yylineno);
                                                                    sym->space = currscopespace();
                                                                    sym->offset = currScopeOffset();
                                                                    incurrscopeoffset();
                                                                }
                                                            }else{
                                                                SymbolType type;
                                                                if (scope==0) type = GLOBAL_;
                                                                else type = LOCAL_;

                                                                binding* sym = SymTable_put(symtab,*$1,scope,type,yylineno);
                                                                sym->space = currscopespace();
                                                                sym->offset = currScopeOffset();
                                                                incurrscopeoffset();
                                                            }
                                                        }
                                                       binding* sym = SymTable_get(symtab,*$1,scope);
                                                       $$ = lval_expr(sym);
                                                    }

                            |   LOCAL ID            {
                                                        islocalid = true;
                                                        if(isLibFunc(*$2)&&(scope!=0)) {
                                                            yyerror(token_node, "Cannot redefine library function \"" + *$2 + "\" as a local variable!");
                                                            YYABORT;
                                                        }
                                                        else {
                                                            SymbolType type;
                                                            if ( !SymTable_lookup(symtab,*$2,scope,true) ) {
                                                                if(scope == 0) type = GLOBAL_;
                                                                else type = LOCAL_;
                                                                binding* sym = SymTable_put(symtab,*$2,scope,type,yylineno);
                                                                sym->space = currscopespace();
                                                                sym->offset = currScopeOffset();
                                                                incurrscopeoffset();
                                                            }
                                                            binding* sym = SymTable_get(symtab,*$2,scope);
                                                            $$ = lval_expr(sym);
                                                        }
                                                    }
                            |   COLCOL ID           {
                                                        if ( !SymTable_lookup(symtab,*$2,0,false) ) {
                                                            yyerror(token_node,"No variable named \"" + *$2 + "\" found in the global namespace!");
                                                            YYABORT;
                                                        }
                                                        else
                                                        {
                                                            binding* sym = SymTable_lookupAndGet(symtab,*$2,scope);
                                                            $$ = lval_expr(sym);
                                                        }
                                                    }
                            |   member { $$ = $1; }
                            ;
member:                         lvalue DOT ID
                                {
                                    $$ = member_item($1,*$3,0,yylineno,scope);
                                }
                            |   lvalue BRACK_L expr BRACK_R
                                {
                                    short_circuit($3,scope,false);
                                    $1 = emit_iftableitem($1,nextquadlabel(),yylineno,scope);
                                    $$ = newexpr(tableitem_e);
                                    $$->sym = $1->sym;
                                    $$->index = $3; // index is the expr
                                }
                            |   call DOT ID  {
                                                isMemberOfFunc = true;
                                                expr* index = newConstStringExpr(*$3);
                                                $$ = newexpr(tableitem_e);
                                                $$->index = index;
                                                $$->sym = $1->sym;
                                             }
                            |   call BRACK_L expr BRACK_R
                                {
                                    expr *result = newexpr(var);
                                    result->sym = newtemp(scope);
                                    emit(tablegetelem, $1, $3, result, nextquadlabel(), yylineno);
                                    $$ = result;
                                }
                            ;

call:                           call PAR_L elist PAR_R  {$$ = make_call($$,$3,scope,yylineno);}
                            |   lvalue callsuffix       {
                                                            if (!isLibFunc($1->sym->key)&&!($1->sym->key=="::")&&!isFunc($1->sym->key,scope)) {

                                                                if (!SymTable_lookup(symtab,$1->sym->key,scope,false)) {
                                                                    yyerror(token_node,"Undefined reference to function \"" + $1->sym->key + "\"!");
                                                                    YYABORT;
                                                                }
                                                            }
                                                            if( !$2->name.empty() ){
                                                                expr* memberItem = member_item($1,$2->name,nextquadlabel(),yylineno,scope);
                                                                expr* originalLval = $1;
                                                                $1 = emit_iftableitem(memberItem,nextquadlabel(),yylineno,scope);
                                                                originalLval->next = $2->elist;
                                                                $2->elist = originalLval;
                                                            }
                                                            $$ = make_call($1,$2->elist,scope,yylineno);
                                                        }
                            |   PAR_L funcdef PAR_R PAR_L elist PAR_R   {
                                                                            $$ = make_call($2,$5,scope,yylineno);
                                                                        }
                            ;
callsuffix:                     normcall                {$$=$1;}
                            |   methodcall              {$$=$1;}
                            ;
normcall:                       PAR_L elist PAR_R       {
                                                        $$ = new method_call;
                                                        $$->elist = $2;
                                                        }
                            ;   // equivalent to lvalue.id(lvalue, elist)
methodcall:                     DOTDOT ID PAR_L elist PAR_R             {
                                                                        $$ = new method_call;
                                                                        $$->elist = $4;
                                                                        $$->name = *$2;
                                                                        }
                            ;
elist:                          expr
                                {   short_circuit($1,scope,false);
                                    $$ = $1;
                                }
                            |   elist COMMA expr
                                {   short_circuit($3,scope,false);
                                    expr* tmp = $$;
                                    while($$->next != nullptr) {
                                        $$ = $$->next;
                                    }
                                    $$->next = $3;
                                    $$ = tmp;
                                }
                            |   %empty {$$=NULL;}
                            ;
objectdef:                      BRACK_L elist BRACK_R
                                {
                                    expr* tmp = $2;
                                    expr* temp = newexpr(newtable_e);
                                    temp->sym = newtemp(scope);
                                    emit(tablecreate,NULL, NULL, temp, nextquadlabel(), yylineno);
                                    for( int i=0; $2; $2 = $2->next)
                                    {
                                        emit(tablesetelem, newConstNumberExpr(i++), $2, temp, nextquadlabel(), yylineno);
                                    }
                                    $$ = temp;
                                }
                            |   BRACK_L indexed BRACK_R
                                {
                                    tup* tmp = $2;
                                    expr* t = newexpr(newtable_e);
                                    t->sym = newtemp(scope);
                                    emit(tablecreate, NULL, NULL, t, nextquadlabel(), yylineno);
                                    for( int i=0; $2; $2 = $2->next) {
                                        emit(tablesetelem, $2->index, $2->value, t, nextquadlabel(), yylineno);
                                    }
                                    $$ = t;
                                }
                            ;
indexed:                        indexedelem
                                {
                                    $$ = $1;
                                }
                            |   indexed COMMA indexedelem
                                {
                                     tup* tempTpl = $$;
                                     while($$->next != nullptr) {
                                        $$ = $$->next;
                                     }
                                     $$->next = $3;
                                     $$ = tempTpl;
                                }
                            ;
indexedelem:                    CBRACK_L expr COL expr CBRACK_R
                                {   short_circuit($4,scope,false);
                                    tup* tuple = new tup;
                                    tuple->index = $2;
                                    tuple->value = $4;
                                    $$ = tuple;
                                }
                            ;
block:                          CBRACK_L{  if (isInsideLoop==true){
                                                isInsideLoop=false;
                                            }else{
                                                stack.push_back(Block);
                                            }
                                            scope++;

                                        } stmtlist CBRACK_R {
                                            stack.pop_back();
                                            scope--;
                                        }
                            ;
funcblock:                  CBRACK_L {} stmtlist CBRACK_R {stack.pop_back(); scope--; SymTable_show(symtab,scope);}
                            ;
funcbody:                   funcblock   {
                                            $$=currScopeOffset(); // extract #locals
                                            exitScopeSpace(); // exit function locals space
                                        }
                            ;
funcargs:                   PAR_L {SymTable_hide(symtab,scope); scope++; stack.push_back(Func);} idlist PAR_R  {
                                                func_args.clear();
                                                $$=currScopeOffset();
                                                enterScopeSpace(); // enter function locals space
                                                resetFunctionLocalOffset(); // start counting locals from zero
                                                }
                            ;
funcprefix:                     FUNCTION ID {if ( SymTable_lookup(symtab,*$2,scope,true) ) {
                                            binding* id = SymTable_get(symtab,*$2,scope);
                                            string binding_type;
                                            if(id->sym == LOCAL_ || id->sym == GLOBAL_ || id->sym == FORMAL_) binding_type = "Variable ";
                                            else {
                                                if(id->sym == USERFUNC_) binding_type = "User function ";
                                                else binding_type = "Library function ";
                                            }
                                                string extras = " already defined on line " + to_string(id->line) +"!";
                                                string msg = binding_type + "\"" + *$2 + "\"" + extras;
                                                yyerror(token_node, msg);
                                                YYABORT;
                                            } else  {
                                                SymTable_put(symtab,*$2,scope,USERFUNC_,yylineno);
                                                $<expr>$ = newexpr(user_func);
                                                $<expr>$->sym = SymTable_get(symtab,*$2,scope);
                                                $<expr>$->sym->funcVal.iaddress = nextquadlabel();
                                                emit(jump, NULL,NULL, NULL,nextquadlabel(),yylineno);
                                                emit(funcstart,NULL,NULL,$<expr>$,0,yylineno);
                                                funcOffsetStack.push_back(currScopeOffset());
                                                enterScopeSpace(); // enter function args scope space
                                                resetFormalArgOffset(); // start formals from zero
                                                }
                                            }
                            |   FUNCTION    {   numOfAnon++;
                                                string key = "_anon"+to_string(numOfAnon);
                                                SymTable_put(symtab,key,scope,USERFUNC_,yylineno);
                                                $<expr>$ = newexpr(user_func);
                                                $<expr>$->sym = SymTable_get(symtab,key,scope);
                                                $<expr>$->sym->funcVal.iaddress = nextquadlabel();
                                                emit(jump, NULL,NULL, NULL,nextquadlabel(),yylineno);
                                                emit(funcstart,NULL,NULL,$<expr>$,0,yylineno);
                                                funcOffsetStack.push_back(currScopeOffset());
                                                enterScopeSpace(); // enter function args scope space
                                                resetFormalArgOffset(); // start formals from zero
                                            }
                            ;
funcdef:                        funcprefix funcargs funcbody{   exitScopeSpace();
                                                                $<expr>$=$1;
                                                                $<expr>$->sym->funcVal.totalargs=$2;
                                                                $<expr>$->sym->funcVal.totallocals=$3;
                                                                if (!return_index.empty()){
                                                                    updatejump2(return_index.back(),nextquadlabel()+1); return_index.pop_back();
                                                                }
                                                                int offset = funcOffsetStack.back(); funcOffsetStack.pop_back();
                                                                restorescopespace(offset);
                                                                emit(funcend,$<expr>$,NULL,NULL,0,yylineno);
                                                                updatejump($<expr>$);
                                                                //cout<<$$->sym->key<<" : ARGS : "<<$$->sym->funcVal.totalargs<<" , LOCALS : "<<$$->sym->funcVal.totallocals<<" , ADDR : "<<$$->sym->funcVal.iaddress<<endl;
                                                            }
                            ;

const:                          REALCONST { $$ = newConstNumberExpr($1); } | INTCONST { $$ = newConstNumberExpr($1);} | STRCONST { $$ = newConstStringExpr(*$1); } | NIL { $$ = newConstNilExpr(); } | TRUE { $$ = newConstBoolExpr(true); } | FALSE { $$ = newConstBoolExpr(false); }
                            ;
idlist:                         ID                                                      {
                                                                                            handleFormalArgs(func_args,string(*$1),scope,token_node);
                                                                                            incurrscopeoffset();
                                                                                        }
                            |   idlist COMMA ID                                         {
                                                                                            handleFormalArgs(func_args,string(*$3),scope,token_node);
                                                                                            incurrscopeoffset();
                                                                                        }
                            |   %empty
                            ;
ifprefix:                       IF PAR_L expr PAR_R     {   short_circuit($3,scope,false);
                                                            emit(if_eq,$3,newConstBoolExpr(true),NULL,nextquadlabel()+3,yylineno);
                                                            $$ = nextquadlabel();
                                                            emit(jump,NULL,NULL,NULL,0,yylineno);
                                                        }
                            ;
elseprefix:                     ELSE                    {
                                                            emit(jump,NULL,NULL,NULL,0,yylineno);
                                                            $$=nextquadlabel();
                                                        }
                            ;
ifstmt:                         ifprefix stmt           {
                                                            updatejump2($1,nextquadlabel()+1);
                                                            $$=$1;
                                                        }
                            |   ifprefix stmt elseprefix stmt  {
                                                            updatejump2($1,$3+1);
                                                            updatejump2($3-1,nextquadlabel()+1);
                                                        }
                            ;

whilestart:                 WHILE
                            {
                                $$ = nextquadlabel()+1;
                            }
                            ;

whilecond:                  PAR_L expr PAR_R
                            {   short_circuit($2,scope,false);
                                emit(if_eq,$2,newConstBoolExpr(true),NULL,nextquadlabel()+3,yylineno);
                                $$=nextquadlabel();
                                emit(jump,NULL,NULL,NULL,0,yylineno);
                                isInsideLoop=true; stack.push_back(Loop);
                            }
                            ;
whilestmt:                      whilestart whilecond stmt
                                {
                                    emit(jump,NULL,NULL,NULL,$1,yylineno);
                                    updatejump2($2,nextquadlabel()+1);
                                    while(!break_index.empty()){
                                        updatejump2(break_index.back(),nextquadlabel()+1); break_index.pop_back();
                                    }
                                    while(!continue_index.empty()){
                                        updatejump2(continue_index.back(),$1); continue_index.pop_back();
                                    }
                                }
                            ;
N:                              { $<intval>$ = nextquadlabel(); emit(jump,NULL,NULL,NULL,0,yylineno); }
                            ;
M:                              { $<intval>$ = nextquadlabel(); }
                            ;
forprefix:                      FOR PAR_L elist SEMICOL M expr SEMICOL  {   short_circuit($6,scope,false);
                                                                            $$ = new forLoop;
                                                                            $$->test = $5;
                                                                            $$->enter = nextquadlabel();
                                                                            emit(if_eq,$6,newConstBoolExpr(true),NULL,0,yylineno);
                                                                        }
                            ;
forstmt:                        forprefix N elist PAR_R{isInsideLoop=true; stack.push_back(Loop);} N stmt N
                                                                        {
                                                                            updatejump2($1->enter,$6+2);
                                                                            updatejump2($2,nextquadlabel()+1);
                                                                            updatejump2($6,$1->test+1);
                                                                            updatejump2($8,$2+2);
                                                                            while(!break_index.empty()){
                                                                                updatejump2(break_index.back(),nextquadlabel()+1); break_index.pop_back();
                                                                            }
                                                                            while(!continue_index.empty()){
                                                                                updatejump2(continue_index.back(),$2+2); continue_index.pop_back();
                                                                            }
                                                                        }
                            ;
returnstmt:                     RETURN SEMICOL      {   emit(ret,NULL,NULL,NULL,0,yylineno);
                                                        emit(jump,NULL,NULL,NULL,0,yylineno);
                                                        return_index.push_back(nextquadlabel()-1);
                                                    }
                            |   RETURN expr SEMICOL {   short_circuit($2,scope,false);
                                                        emit(ret,$2,NULL,NULL,0,yylineno);
                                                        emit(jump,NULL,NULL,NULL,0,yylineno);
                                                        return_index.push_back(nextquadlabel()-1);
                                                    }
                            ;

%%

int yyerror(alpha_token_t token,string msg){
    cerr<< ANSI_COLOR_RED << "[Error] on line " << yylineno << ": " << msg << ANSI_COLOR_RESET << endl;
    return 0;
}