//
// Created by Steli on 25/5/2022.
//

#ifndef CS_340_COMPILER_TARGET_CODE_GEN_H
#define CS_340_COMPILER_TARGET_CODE_GEN_H

#include "../avm/avm_instr_set.h"
#include "../utils/parser-utils.hpp"
#include <cassert>
#include <algorithm>

struct incomplete_jump {
    unsigned int instrNo; // jump instruction number
    unsigned int iaddress; // i-code jump-target address
    //incomplete_jump *next;
};

void patch_incomplete_jumps();

unsigned int nextInstructionLabel();

void add_incomplete_jump(unsigned int i_label, unsigned int quad_label);

void emit_instr(instruction instr);

void generate(vmopcode op, quad *q);

void generate_relational(vmopcode op, quad *q);

// arithmetic expressions
void generate_ADD(quad *q);

void generate_SUB(quad *q);

void generate_MUL(quad *q);

void generate_DIV(quad *q);

void generate_MOD(quad *q);

void generate_UMINUS(quad *q);

// table-related
void generate_NEWTABLE(quad *q);

void generate_TABLEGETELEM(quad *q);

void generate_TABLESETELEM(quad *q);

// other expressions

void generate_ASSIGN(quad *q);

void generate_NOP(quad *q);

// relational expressions
void generate_JUMP(quad *q);

void generate_IF_EQ(quad *q);

void generate_IF_NEQ(quad *q);

void generate_IF_GRTR(quad *q);

void generate_IF_GRTR_EQ(quad *q);

void generate_IF_LESS(quad *q);

void generate_IF_LESS_EQ(quad *q);


void make_operand(expr *exp, vmarg *arg);

unsigned int consts_newstring(string str);

unsigned int consts_newnumber(double num);

unsigned int libfuncs_newused(string name);

unsigned int userfuncs_newfunc(binding *sym, unsigned int address);

// helper functions for producing common args
// for generated instructions like 1,0, "true", "false"
// and function return values
void make_num_operand(vmarg *arg, double val);

void make_bool_operand(vmarg *arg, bool val);

void make_retval_operand(vmarg *arg);

void generate_NOT(quad *q);

void generate_AND(quad *q);

void generate_OR(quad *q);

void generate_PARAM(quad *q);

void generate_CALL(quad *q);

void generate_GETRETVAL(quad *q);

void generate_FUNCSTART(quad *q);

void generate_RETURN(quad *q);

void generate_FUNCEND(quad *q);

typedef void (*generator_func_t)(quad *);

static generator_func_t generators[] = {
        generate_ASSIGN,
        generate_ADD,
        generate_SUB,
        generate_MUL,
        generate_DIV,
        generate_MOD,
        generate_UMINUS,
        generate_AND,
        generate_OR,
        generate_NOT,
        generate_IF_EQ,
        generate_IF_NEQ,
        generate_IF_LESS_EQ,
        generate_IF_GRTR_EQ,
        generate_IF_LESS,
        generate_IF_GRTR,
        generate_CALL,
        generate_PARAM,
        generate_RETURN,
        generate_GETRETVAL,
        generate_FUNCSTART,
        generate_FUNCEND,
        generate_NEWTABLE,
        generate_TABLEGETELEM,
        generate_TABLESETELEM,
        generate_JUMP,
        generate_NOP
};

void generate_target_code();

static void print_const_num_table();

static void print_const_bool_table();

static void print_const_str_table();

static void print_const_libfunc_table();

static void print_const_userfunc_table();

void print_const_tables();

void print_target_code();

void createbin();

#endif //CS_340_COMPILER_TARGET_CODE_GEN_H
