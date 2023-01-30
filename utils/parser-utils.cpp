#include "parser-utils.hpp"

using namespace std;

unsigned int countertemp = 0;
unsigned int currQuad = 0;

void handleFormalArgs(vector <string> &func_args, string arg, unsigned int scope, alpha_token_t token_node) {
    if (find(func_args.begin(), func_args.end(), arg) != func_args.end()) { // contains the ID
        binding *binding = SymTable_get(symtab, arg, scope);
        yyerror(token_node,
                "Variable \"" + arg + "\" already defined as formal parameter on line " + to_string(binding->line) +
                "!");
    } else {
        func_args.push_back(arg);
        if (isLibFunc(arg)) yyerror(token_node, "Formal parameter \"" + arg + "\" shadows library function!");
        else {
            binding *sym = SymTable_put(symtab, arg, scope, FORMAL_, yylineno);
            sym->space = currscopespace();
            sym->offset = currScopeOffset();
        }
    }
}

bool isLibFunc(string id) {
    vector <string> libFuncs{"print", "input", "objectmemberkeys", "objecttotalmembers", "objectcopy", "totalarguments",
                             "argument", "typeof", "strtonum", "sqrt", "cos", "sin"};
    return (find(libFuncs.begin(), libFuncs.end(), id) != libFuncs.end());
}

int isFunc(string id, int scope) {
    binding *tmp = SymTable_lookupAndGet(symtab, id, scope);
    if (tmp) if (tmp->sym == USERFUNC_) { return 1; }
    return 0;
}

expr *newexpr(expr_t exprt) {
    expr *current = new expr;
    current->sym = NULL;
    current->index = NULL;
    current->numConst = 0;
    current->strConst = "";
    current->boolConst = false;
    current->next = NULL;
    current->type = exprt;
    return current;
}

string newTempName() {
    string temp = "_t" + to_string(countertemp);
    countertemp++;
    return temp;
}

void resettemp() {
    SymTable_removeTempVars(symtab);
    countertemp = 0;
}

scopespace_t currscopespace() {
    if (scopeSpaceCounter == 1) return programVar;
    else if (scopeSpaceCounter % 2 == 0) return formalArg;
    else return functionLocal;
}

binding *newtemp(unsigned int scope) {
    string name = newTempName();
    binding *sym = SymTable_get(symtab, name, scope);
    if (sym == nullptr) {
        binding *sym = SymTable_put(symtab, name, scope, TEMP, -1);
        sym->space = currscopespace();
        sym->offset = currScopeOffset();
        incurrscopeoffset();
        return sym;
    } else return sym;
}

void incurrscopeoffset() {
    switch (currscopespace()) {
        case programVar    :
            ++programVarOffset;
            break;
        case functionLocal  :
            ++functionLocalOffset;
            break;
        case formalArg        :
            ++formalArgOffset;
            break;
        default            :
            cerr << "PROBLEM" << endl;
    }
}

void resetFormalArgOffset() {
    formalArgOffset = 0;
}

void resetFunctionLocalOffset() {
    functionLocalOffset = 0;
}

void enterScopeSpace() { ++scopeSpaceCounter; }

void exitScopeSpace() {
    if (scopeSpaceCounter <= 1) {
        cerr << "ERROR: scopeSpaceCounter is <= 1 and exit scope was called!" << endl;
        return;
    }
    --scopeSpaceCounter;
}

void emit(
        iopcode op,
        expr *arg1,
        expr *arg2,
        expr *result,
        unsigned int label,
        unsigned int line
) {
    quad p;
    p.op = op;
    p.arg1 = arg1;
    p.arg2 = arg2;
    p.result = result;
    p.label = label;
    p.line = line;
    currQuad++;
    quads.push_back(p);
}

expr *emit_iftableitem(expr *e, int quadno, int line, unsigned int scope) {
    if (e->type != tableitem_e) return e;
    else {
        expr *result = newexpr(var);
        result->sym = newtemp(scope);
        emit(tablegetelem, e, e->index, result, quadno, line);
        return result;
    }
}

expr *newConstStringExpr(string val) {
    expr *expr = newexpr(const_string);
    expr->strConst = val;
    return expr;
}

expr *newConstNumberExpr(double val) {
    expr *expr = newexpr(const_num);
    expr->numConst = val;
    return expr;
}

expr *newConstBoolExpr(bool val) {
    expr *expr = newexpr(const_bool);
    expr->boolConst = val;
    return expr;
}

expr *member_item(expr *lval, string name, int quadno, int line, unsigned int scope) {
    lval = emit_iftableitem(lval, quadno, line, scope); // Emit code if r-value use of table item
    expr *item = newexpr(tableitem_e);
    item->sym = lval->sym;
    item->index = newConstStringExpr(name);
    return item;
}

expr *lval_expr(binding *binding) {
    expr_t type;
    switch (binding->sym) {
        case GLOBAL_ :
            type = var;
            break;
        case LOCAL_:
            type = var;
            break;
        case FORMAL_:
            type = var;
            break;
        case USERFUNC_:
            type = user_func;
            break;
        case LIBFUNC_:
            type = lib_func;
            break;
        default:
            cout << "Invalid lval_expr symbol type!" << endl;
    }
    expr *expr = newexpr(type);
    expr->sym = binding;
    return expr;
}

expr *newConstNilExpr() {
    expr *expr = newexpr(nil_e);
    return expr;
}

const string BoolToString(const bool b) {
    return b ? "true" : "false";
}

bool check_arith(expr *e) {
    return e->type == const_num;
}

bool isNonArithmeticConstValue(expr *e) {
    return e->type == const_bool || e->type == const_string || e->type == nil_e;
}

void patchlabel(unsigned int quadno, unsigned int label) {
    if (quadno >= currQuad) cerr << "PROBLEM AT PATCHLABEL" << endl;
    quads[quadno].result = newConstNumberExpr(label);
}

int nextquadlabel() { return currQuad; }


void patchlist(vector<unsigned int> list, int quadno) {
    for (int i = 0; i < list.size(); i++) {
        updatejump2(list.at(i), quadno);
    }
}

vector<unsigned int> mergelists(vector<unsigned int> lista, vector<unsigned int> listb) {
    vector<unsigned int> returnlist;
    for (int i = 0; i < lista.size(); i++) returnlist.push_back(lista.at(i));
    for (int i = 0; i < listb.size(); i++) returnlist.push_back(listb.at(i));
    return returnlist;
}

expr *make_call(expr *lvalue, expr *elist, int scope, int line) {
    expr *func = emit_iftableitem(lvalue, nextquadlabel(), line, scope);
    vector < expr * > tmp;
    expr *temp = elist;
    binding *b = nullptr;
    while (temp != nullptr) {
        tmp.push_back(temp);
        temp = temp->next;
    }
    for (int i = tmp.size() - 1; i >= 0; --i) {
        emit(param, tmp.at(i), NULL, NULL, 0, line);
        if (istempexpr(tmp.at(i))) b = tmp.at(i)->sym;
    }
    emit(call, NULL, NULL, func, 0, line);
    expr *result = newexpr(var);
    result->sym = newtemp(scope);
    emit(getretval, NULL, NULL, result, 0, line);
    return result;
}

bool isConvertableToBool(expr *exp) {
    bool result = false;
    switch (exp->type) {
        case var:
            result = false;
            break;
        case tableitem_e:
            result = false;
            break;
        case arithmetic_e:
            result = false;
            break;
        case assignment:
            result = false;
            break;
        default:
            result = true;
    }
    return result;
}

bool convert_to_bool(expr *exp) {
    bool result = false;
    switch (exp->type) {
        case const_bool:
            result = exp->boolConst;
            break;
        case const_num:
            result = exp->numConst != 0;
            break;
        case user_func:
            result = true;
            break;
        case lib_func:
            result = true;
            break;
        case newtable_e:
            result = true;
            break;
        case nil_e:
            result = false;
            break;
        case const_string:
            result = !(exp->strConst.empty());
            break;
        default:
            result = false;
    }
    return result;
}

unsigned int currScopeOffset() {
    switch (currscopespace()) {
        case programVar        :
            return programVarOffset;
        case functionLocal    :
            return functionLocalOffset;
        case formalArg        :
            return formalArgOffset;
        default                : {
            cerr << "ERROR AT CURRSCOPEOFFSET FUNCTION" << endl;
            return -1;
        }
    }
}

void updatejump(expr *e) {
    string key = e->sym->key;
    for (int i = 0; i < quads.size(); i++) {
        if (quads.at(i).result != NULL) {
            if (quads.at(i).result->sym != NULL) {
                if (quads.at(i).result->sym->key == key && quads.at(i).op == funcstart) {
                    if (i - 1 >= 0) quads.at(i - 1).label = nextquadlabel() + 1;
                }
            }
        }
    }
}

void updatejump2(int quadno, int newlabel) {
    if (quadno < 0 || quadno >= quads.size()) cerr << "PROBLEM AT UPDATEJUMP2" << endl;
    quads.at(quadno).label = newlabel;
}

unsigned int istempname(string s) {
    return s[0] == '_';
}

unsigned int istempexpr(expr *e) {
    return e->sym && istempname(e->sym->key);
}

void restorescopespace(unsigned int offset) {
    switch (currscopespace()) {
        case programVar    :
            programVarOffset = offset;
            break;
        case functionLocal  :
            functionLocalOffset = offset;
            break;
        case formalArg        :
            formalArgOffset = offset;
            break;
        default            :
            cerr << "PROBLEM" << endl;
    }
}

void short_circuit(expr *e, int scope, bool type) {
    if (type == true) {
        if (e->type == bool_e || e->flag == true) {
            e->sym = newtemp(scope);
            patchlist(e->truelist, nextquadlabel() + 1);
            emit(assign, newConstBoolExpr(true), NULL, e, nextquadlabel(), yylineno);
            emit(jump, NULL, NULL, NULL, nextquadlabel() + 3, yylineno);
            patchlist(e->falselist, nextquadlabel() + 1);
            emit(assign, newConstBoolExpr(false), NULL, e, nextquadlabel(), yylineno);
        }
    } else {
        if (e->type == bool_e) {
            e->sym = newtemp(scope);
            patchlist(e->truelist, nextquadlabel() + 1);
            emit(assign, newConstBoolExpr(true), NULL, e, nextquadlabel(), yylineno);
            emit(jump, NULL, NULL, NULL, nextquadlabel() + 3, yylineno);
            patchlist(e->falselist, nextquadlabel() + 1);
            emit(assign, newConstBoolExpr(false), NULL, e, nextquadlabel(), yylineno);
        }
    }
}

void patchlist2(vector<int> list, int quadno) {
    for (int i = 0; i < list.size(); i++) {
        updatejump2(list.at(i) - 2, quadno - 1);
    }
}