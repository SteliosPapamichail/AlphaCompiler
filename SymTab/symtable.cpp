/*	Nikolaos Giovanopoulos - CSD4613
	ASSIGNMENT 3	
	symtablehash.c
*/

#include "symtable.h"
#include <algorithm>

bool isHidingBindings = false;

/* Return a hash code for pcKey.*/
static unsigned int SymTable_hash(string pcKey) {
    size_t ui;
    unsigned int uiHash = 0U;
    for (ui = 0U; pcKey[ui] != '\0'; ui++)
        uiHash = uiHash * HASH_MULTIPLIER + pcKey[ui];
    return (uiHash % DEFAULT_SIZE);
}

/*If b contains a binding with key pcKey, returns 1.Otherwise 0.
It is a checked runtime error for oSymTable and pcKey to be NULL.*/
int Bucket_contains(scope_bucket b, string pcKey) {
    deque <binding> current = b.entries[SymTable_hash(pcKey)]; /*find the entry binding based on the argument pcKey*/
    for (int i = 0; i < current.size(); i++) {
        binding cur = current.at(i);
        if (cur.key == pcKey) return 1;
    }
    return 0;
}

/*epistrefei to index gia to bucket pou antistixei sto scope 'scope'.Se periptwsh pou den uparxei
akoma bucket gia to en logw scope, ean to create einai true dhmiourgei to antistoixo bucket sto
oSymTable kai epistrefei to index tou.Diaforetika epistrefei thn timh -1.*/
int indexofscope(SymTable_T &oSymTable, unsigned int scope, bool create) {
    int index = -1;
    for (int i = 0; i < oSymTable.buckets.size(); i++) if (oSymTable.buckets[i].scope == scope) index = i;
    if (index == -1 && create) {
        scope_bucket newbucket;
        newbucket.scope = scope;
        oSymTable.buckets.push_back(newbucket);
        index = oSymTable.buckets.size() - 1;
    }
    return index;
}

/*If there is no binding with key : pcKey in oSymTable, puts a new binding with
this key and value : pvvValue returning 1.Otherise, it just returns 0.
It is a checked runtime error for oSymTable and pcKey to be NULL.*/
binding *SymTable_put(SymTable_T &oSymTable, string pcKey, unsigned int scope, SymbolType st, unsigned int line) {
    int index = indexofscope(oSymTable, scope, true);
    if (index == -1) {
        cerr << "ERROR" << endl;
        return nullptr;
    }
    scope_bucket *current = &oSymTable.buckets.at(index);
    if (Bucket_contains(*current, pcKey) && st != FORMAL_ && st != LOCAL_)
        return 0; /*If the binding exists in oSymTable return 0.*/
    binding newnode;
    newnode.key = pcKey;
    newnode.isactive = true;
    newnode.line = line;
    newnode.sym = st;
    newnode.scope = scope;
    current->entries[SymTable_hash(pcKey)].push_back(newnode);
    return &current->entries[SymTable_hash(pcKey)].back();
}

/*Pairnei ws orisma to oSymTable kai to scope pou theloume na apenergopoihsoume.
An to sugkekrimeno scope den uparxei sto oSymTable epistrefei -1.Diaforetika 0*/
void SymTable_hide(SymTable_T &oSymTable, unsigned int scope) {
    isHidingBindings = true;
    for (int i = scope; i >= 0; i--) {
        if (i == 0) return;
        int index = indexofscope(oSymTable, i, false);
        if (index == -1) continue;
        scope_bucket *current = &oSymTable.buckets.at(index);
        for (int i = 0; i < DEFAULT_SIZE; i++) {
            for (int j = 0; j < current->entries[i].size(); j++) {
                if (current->entries[i].at(j).sym == LOCAL_ || current->entries[i].at(j).sym == FORMAL_)
                    current->entries[i].at(j).isactive = false;
            }
        }
    }
}

void SymTable_show(SymTable_T &oSymTable, unsigned int scope) {
    isHidingBindings = false;
    for (int i = scope; i >= 0; i--) {
        if (i == 0) return;
        int index = indexofscope(oSymTable, i, false);
        if (index == -1) continue;
        scope_bucket *current = &oSymTable.buckets.at(index);
        for (int i = 0; i < DEFAULT_SIZE; i++) {
            for (int j = 0; j < current->entries[i].size(); j++) {
                if (current->entries[i].at(j).sym == LOCAL_ || current->entries[i].at(j).sym == FORMAL_)
                    current->entries[i].at(j).isactive = true;
            }
        }
    }
}

bool SymTable_lookup(SymTable_T oSymTable, string pcKey, unsigned int scope, bool searchInScopeOnly) {
    for (int i = scope; i >= 0; i--) {
        if (searchInScopeOnly && i != scope) break;
        int index = indexofscope(oSymTable, i, false);
        if (index == -1) continue;
        scope_bucket current = oSymTable.buckets[index];
        for (deque <binding> entry: current.entries) {
            for (binding b: entry) {
                if (b.key == pcKey && b.isactive) return true;
                else if (b.key == pcKey && !b.isactive) return false;
            }
        }
    }
    return false;
}

binding *SymTable_lookupAndGet(SymTable_T &oSymTable, string pcKey, unsigned int scope)

noexcept{
for (
int i = scope;
i >= 0; --i ){
int index = indexofscope(oSymTable, i, false);
if (index==-1) continue;
scope_bucket &current = oSymTable.buckets[index];
for (
auto &entry
: current.entries) {
for (
auto &b
: entry ){
if ( b.key == pcKey ) return &
b;
}
}
}
return
nullptr;
}

/*Lamvanei ws orisma to oSymTable, kleidh tou tou desmou pou psaxnoume kai to scope tou desmou.
H sunarthsh telika epistrefei to value tou tou desmou.Diaforetika epistrefei 0*/
binding *SymTable_get(SymTable_T &oSymTable, const string pcKey, unsigned int scope) {
    for (int i = scope; i >= 0; --i) {
        const int index = indexofscope(oSymTable, i, false);
        if (index == -1) {
            continue;
        }

        scope_bucket &current = oSymTable.buckets[index];

        for (auto &entry: current.entries) {
            for (auto &b: entry) {
                if (b.key == pcKey) {
                    return &b;
                }
            }
        }
    }
    return nullptr;
}


void SymTable_removeTempVars(SymTable_T oSymTable) {
    int index = indexofscope(oSymTable, 0, false);
    scope_bucket current = oSymTable.buckets[index];
    for (deque <binding> entry: current.entries) {
        for (int j = 0; j < entry.size(); j++) {
            if (entry.at(j).sym == TEMP) entry.erase(entry.begin() + j);
        }
    }
}

bool compareBinding(binding b1, binding b2) {
    return (b1.line < b2.line);
}

void printSymTable(SymTable_T oSymTable) {
    for (int i = 0; i < oSymTable.buckets.size(); i++) {
        scope_bucket *bucket = &oSymTable.buckets.at(i);
        deque <binding> tmp;
        cout << "\n----------------\tScope #" << bucket->scope << "\t----------------" << endl;
        for (deque <binding> entry: bucket->entries) {
            if (entry.empty()) continue;
            for (int i = 0; i < entry.size(); i++) { tmp.push_back(entry.at(i)); }
        }
        sort(tmp.begin(), tmp.end(), compareBinding);
        for (int i = 0; i < tmp.size(); i++) {
            if (tmp[i].sym == TEMP) continue; // skip temp vars
            cout << "\"" << tmp[i].key << "\"" << "\t[" << SymbolTypeToString[tmp[i].sym] << "]" << "\t(line "
                 << tmp[i].line << ")" << "\t(scope " << tmp[i].scope << ")";
            SymbolType type = tmp[i].sym;
            if (type == LIBFUNC_ || type == USERFUNC_ || type == TEMP) cout << endl;
            else cout << "\t" << ScopeSpaceToString[tmp[i].space] << "\t" << tmp[i].offset << endl;
        }
    }
}