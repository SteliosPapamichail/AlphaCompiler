//
// Created by Steli on 25/5/2022.
//

#ifndef CS_340_COMPILER_AVM_IMPL_H
#define CS_340_COMPILER_AVM_IMPL_H

#include <vector>
#include <string>
#include <assert.h>
#include "../SymTab/symtable.h"

using namespace std;

enum vmopcode {
    assign_v, add_v, sub_v, mul_v,
    div_v, mod_v, uminus_v, and_v, or_v,
    not_v, jump_v, jeq_v, jne_v, jle_v, jge_v, jlt_v,
    jgt_v, call_v, pusharg_v, funcenter_v,
    funcexit_v, newtable_v, tablegetelem_v,
    tablesetelem_v, nop_v
};

const string vmopcodeStrings[] = {
        "assign", "ADD", "SUB", "MUL", "DIV", "MOD", "uminus", "AND", "OR", "NOT",
        "jump", "jeq", "jne",
        "jle", "jge", "jlt", "jgt", "call", "pusharg", "funcenter",
        "funcexit", "newtable", "tablegetelem",
        "tablesetelem", "nop"
};

enum vmarg_t {
    label_a = 0,
    global_a = 1,
    formal_a = 2,
    local_a = 3,
    number_a = 4,
    string_a = 5,
    bool_a = 6,
    nil_a = 7,
    userfunc_a = 8,
    libfunc_a = 9,
    retval_a = 10
};

const string vmargStrings[] = {
        "label", "global", "formal",
        "local", "number", "string",
        "bool", "nil", "userfunc",
        "libfunc", "retval"
};

struct vmarg {
    vmarg_t type;
    unsigned int val;
    string var_id; // only used for debug printing during tcode
    bool is_null = true;
};

struct instruction {
    vmopcode opcode;
    vmarg result;
    vmarg arg1;
    vmarg arg2;
    unsigned int srcLine;
};

struct userfunc {
    unsigned int address;
    unsigned int total_locals;
    string id;
};

#endif //CS_340_COMPILER_AVM_IMPL_H