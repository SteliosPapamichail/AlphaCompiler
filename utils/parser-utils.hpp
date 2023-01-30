#ifndef __PARSER_UTILS_HPP__
#define __PARSER_UTILS_HPP__

#include <algorithm>
#include <vector>
#include "../SymTab/symtable.h"
#include "../settings.h"

// **** Quad handling ****
enum iopcode {
    assign, add, sub, mul, div_op, mod_op, uminus, and_op, or_op,
    not_op, if_eq, if_noteq, if_lesseq, if_greatereq, if_less,
    if_greater, call, param, ret, getretval, funcstart, funcend,
    tablecreate, tablegetelem, tablesetelem, jump
};

static const string opcodeStrings[] = {"assign", "ADD", "SUB", "MUL", "DIV", "MOD", "uminus", "AND", "OR", "NOT",
                                       "if_eq", "if_noteq",
                                       "if_lesseq", "if_greatereq", "if_less", "if_greater", "call", "param", "ret",
                                       "getretval", "funcstart", "funcend",
                                       "tablecreate", "tablegetelem", "tablesetelem", "jump"};

enum expr_t {
    var,
    tableitem_e,
    user_func,
    lib_func,
    arithmetic_e,
    assignment,
    newtable_e,
    const_num,
    const_bool,
    const_string,
    nil_e,
    bool_e
};

struct expr {
    expr_t type;
    binding *sym;
    expr *index;
    double numConst;
    string strConst;
    bool boolConst;
    expr *next;
    bool flag = false;
    vector<unsigned int> truelist;
    vector<unsigned int> falselist;
};

struct quad {
    iopcode op;
    expr *result;
    expr *arg1;
    expr *arg2;
    unsigned int taddress;
    unsigned int label;
    unsigned int line;
};

struct tup {
    struct expr *index;
    struct expr *value;
    struct tup *next = nullptr;
};

struct forLoop {
    int test;
    int enter;
};

struct method_call {
    expr *elist;
    string name;
};

// *** Helper variables ***
extern unsigned int scopeSpaceCounter;
extern unsigned int programVarOffset;
extern unsigned int functionLocalOffset;
extern unsigned int formalArgOffset;

// *** External declarations ***
extern SymTable_T symtab;
extern int yylineno;

extern int yyerror(alpha_token_t node, string msg);

extern vector <quad> quads;

// *** Function declarations ***
bool isLibFunc(string);

int isFunc(string id, int scope);

void handleFormalArgs(vector <string> &args, string arg, unsigned int scope, alpha_token_t token_node);

//
expr *newexpr(expr_t exprt);

expr *newConstStringExpr(string val);

expr *newConstNumberExpr(double val);

expr *newConstBoolExpr(bool val);

expr *newConstNilExpr();

expr *member_item(expr *lval, string name, int quadno, int line, unsigned int scope);

expr *lval_expr(binding *sym);

void resettemp();

scopespace_t currscopespace();

binding *newtemp(unsigned int scope);

void resetFormalArgOffset();

void resetFunctionLocalOffset();

void incurrscopeoffset();

void enterScopeSpace();

void exitScopeSpace();

void emit(
        iopcode op,
        expr *arg1,
        expr *arg2,
        expr *result,
        unsigned int label,
        unsigned int line
);

expr *emit_iftableitem(expr *e, int quadno, int line, unsigned int scope);

const string BoolToString(const bool b);

bool check_arith(expr *e);

string newTempName();

void patchlabel(unsigned int quadno, unsigned int label);

int nextquadlabel();

void patchlist(vector<unsigned int> list, int quadno);

vector<unsigned int> mergelists(vector<unsigned int> lista, vector<unsigned int> listb);

expr *make_call(expr *lvalue, expr *elist, int scope, int line);

bool convert_to_bool(expr *exp);

bool isConvertableToBool(expr *exp);

bool isNonArithmeticConstValue(expr *e);

void updatejump2(int quadno, int newlabel);

void updatejump(expr *e);

unsigned int currScopeOffset();

unsigned int istempexpr(expr *e);

void restorescopespace(unsigned int offset);

void short_circuit(expr *e, int scope, bool type);

#endif