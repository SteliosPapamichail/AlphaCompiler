#ifndef _SYMTABLE_H_
#define _SYMTABLE_H_

using namespace std;

#include <string>
#include <iostream>
#include <deque>
#include <string_view>

#define DEFAULT_SIZE 300
#define HASH_MULTIPLIER 65599
#define MAX_HASH 65521
enum SymbolType {
    GLOBAL_, LOCAL_, FORMAL_, USERFUNC_, LIBFUNC_, TEMP
};
static const string SymbolTypeToString[] = {"Global variable", "Local variable", "Formal parameter", "User function",
                                            "Library function"};
static const string ScopeSpaceToString[] = {"programVar", "functionLocal", "formalArg"};

enum scopespace_t {
    programVar,
    functionLocal,
    formalArg
};
//PHASE3
struct returnList {
    unsigned int instrLabel;
    struct returnList *next = nullptr;
};

struct Function {
    unsigned int totalargs;
    unsigned int iaddress;
    unsigned int totallocals;
    unsigned int taddress;
    struct returnList *returnList = nullptr;
};
//PHASE3

struct binding {
    std::string key;
    bool isactive = true;
    SymbolType sym;
    //vector<binding *> formals;
    scopespace_t space;
    unsigned int offset;
    unsigned int scope;
    int line;
    Function funcVal;

};

struct scope_bucket {
    unsigned int scope;
    deque <binding> entries[DEFAULT_SIZE];
};

struct symtable {
    deque <scope_bucket> buckets;
};

typedef struct symtable SymTable_T;

static unsigned int SymTable_hash(string pcKey);

/*Creates a new SymTable containing no bindings and returns it.*/
SymTable_T SymTable_new(void);

/*If oSymTable isn't NULL, frees all it's allocated memory*/
void SymTable_free(SymTable_T oSymTable);

int Bucket_contains(scope_bucket b, string pcKey);

/*If there is no binding with key : pcKey in oSymTable, puts a new binding with
this key and value : pvvValue returning 1.Otherise, it just returns 0.
It is a checked runtime error for oSymTable and pcKey to be NULL.*/
binding *SymTable_put(SymTable_T &oSymTable, string pcKey, unsigned int scope, SymbolType st, unsigned int line);

void SymTable_hide(SymTable_T &oSymTable, unsigned int scope);

void SymTable_show(SymTable_T &oSymTable, unsigned int scope);

/*Returns the value of binding with key pcKey from oSymTable.If the binding does not exist NULL
It is a checked runtime error for oSymTable and pcKey to be NULL.*/
binding *SymTable_get(SymTable_T &oSymTable, string pcKey, unsigned int scope);

bool SymTable_lookup(SymTable_T oSymTable, string pcKey, unsigned int scope, bool searchInScopeOnly);

binding *SymTable_lookupAndGet(SymTable_T &oSymTable, string pcKey, unsigned int scope)

noexcept;

void SymTable_removeTempVars(SymTable_T oSymTable);

void printSymTable(SymTable_T oSymTable);

#endif