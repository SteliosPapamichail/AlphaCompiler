#include "./parser/parser.h"
#include "./utils/parser-utils.hpp"
#include "./target_code/target_code_gen.h"
#include <cstring>
// define ansi escape codes to support colorful output
#define ANSI_COLOR_RED     "\x1b[31m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_RESET   "\x1b[0m"
extern FILE *yyin;
extern SymTable_T symtab;
alpha_token_t head = NULL;
bool DEBUG_ENABLED = false;

void printTokensList() {
    alpha_token_t ptr = head;
    cout << "--- Printing tokens list ---" << endl;
    while (ptr) {
        cout << "line=" << ptr->line << ":  #" << ptr->token_number << "\t  \"" << ptr->content << "\"\t\t"
             << TOKEN_T_STRING[ptr->token_type] << endl;
        ptr = ptr->next;
    }
    cout << "--- Finished printing tokens list ---" << endl;
}

void printQuads() {
    unsigned int index = 0;
    cout << "quad#\t\topcode\t\tresult\t\targ1\t\targ2\t\tlabel" << endl;
    cout << "-------------------------------------------------------------------------------------------------" << endl;
    for (quad q: quads) {
        string arg1_type = "";
        string arg2_type = "";
        if (q.arg1 != nullptr) {
            switch (q.arg1->type) {
                case const_bool:
                    arg1_type = "\'" + BoolToString(q.arg1->boolConst) + "\'";
                    break;
                case const_string:
                    arg1_type = "\"" + q.arg1->strConst + "\"";
                    break;
                case const_num:
                    arg1_type = to_string(q.arg1->numConst);
                    break;
                case var:
                    arg1_type = q.arg1->sym->key;
                    break;
                case nil_e:
                    arg1_type = "nil";
                    break;
                default:
                    arg1_type = q.arg1->sym->key;
                    break;
            }
        }
        if (q.arg2 != nullptr) {
            switch (q.arg2->type) {
                case const_bool:
                    arg2_type = "\'" + BoolToString(q.arg2->boolConst) + "\'";
                    break;
                case const_string:
                    arg2_type = "\"" + q.arg2->strConst + "\"";
                    break;
                case const_num:
                    arg2_type = to_string(q.arg2->numConst);
                    break;
                case nil_e:
                    arg2_type = "nil";
                    break;
                default:
                    arg2_type = q.arg2->sym->key;
                    break;
            }
        }
        string label = "";
        if (q.op == if_eq || q.op == if_noteq || q.op == if_lesseq || q.op == if_greatereq
            || q.op == if_less || q.op == if_greater || q.op == jump) {
            label = to_string(q.label);
        }

        string resultKey = "";
        if (q.result != nullptr && q.result->sym != nullptr) {
            resultKey = q.result->sym->key;
        }
        cout << index << ":\t\t" << opcodeStrings[q.op] << "\t\t" << resultKey << "\t\t" << arg1_type << "\t\t"
             << arg2_type << "\t\t" << label << "\t\t" << endl;
        index++;
    }
}

void fillLibFuncs() {
    SymTable_put(symtab, "print", 0, LIBFUNC_, 0);
    SymTable_put(symtab, "input", 0, LIBFUNC_, 0);
    SymTable_put(symtab, "objecttotalmembers", 0, LIBFUNC_, 0);
    SymTable_put(symtab, "objectcopy", 0, LIBFUNC_, 0);
    SymTable_put(symtab, "totalarguments", 0, LIBFUNC_, 0);
    SymTable_put(symtab, "argument", 0, LIBFUNC_, 0);
    SymTable_put(symtab, "typeof", 0, LIBFUNC_, 0);
    SymTable_put(symtab, "strtonum", 0, LIBFUNC_, 0);
    SymTable_put(symtab, "sqrt", 0, LIBFUNC_, 0);
    SymTable_put(symtab, "cos", 0, LIBFUNC_, 0);
    SymTable_put(symtab, "sin", 0, LIBFUNC_, 0);
}

void freeTokensList() {
    alpha_token_t tmp = head;
    while (head) {
        tmp = head->next;
        delete head;
        head = tmp;
    }
}

int main(int argc, char *argv[]) {
    if (argc == 1) {
        cout << "Usage: ./exec [program_path].asc [optional -d]" << endl;
        return -1;
    } else if(argc == 2) {
        if (!(yyin = fopen(argv[1], "r"))) {
            fprintf(stderr, "Cannot read file %s\n", argv[1]);
            return -1;
        }
    } else if(argc == 3) {
        if(strcmp(argv[2],"-d") == 0) DEBUG_ENABLED = true;
        if (!(yyin = fopen(argv[1], "r"))) {
            fprintf(stderr, "Cannot read file %s\n", argv[1]);
            return -1;
        }
    } else {
        cout << "Too many arguments." << endl;
        cout << "Usage: ./exec [program_path].asc [optional -d]" << endl;
        return -1;
    }

    int result;
    fillLibFuncs();
    do {
        alpha_token_t node; // the parser will pass a new alpha_token_t instance with each call to yylex so the allocation happens inside of lexer.l
        result = yyparse(node);
        if (result == 1) break; // YY_ABORT was called
        ///*ucomment to see the list:*/ if(result == 0) printTokensList();
    } while (result != 0);
    if (result != 1) {
        if(DEBUG_ENABLED) {
            printSymTable(symtab);
            printf("\n----------------\tSyntax Analysis finished successfully!\t----------------\n\n");
            printQuads();
        }
        // create target code
        generate_target_code();
        if(DEBUG_ENABLED) {
            print_const_tables();
            print_target_code();
        }
        createbin();
    } else
        cerr << ANSI_COLOR_RED << "\n----------------\tSyntax Analysis failed!\t----------------" << ANSI_COLOR_RESET
             << endl;
    freeTokensList();
    fclose(yyin);
    return 0;
}