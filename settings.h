#ifndef _SETTINGS_H_
#define _SETTINGS_H_

#include <iostream>
#include <unistd.h>
#include <string>
using namespace std;
#define FOREACH_TOKEN_T(TOKEN_T) \
        TOKEN_T(UNKNOWN)   \
        TOKEN_T(KEYWORD)  \
        TOKEN_T(INT_CONST)   \
        TOKEN_T(OPERATOR)  \
        TOKEN_T(REAL_CONST)  \
        TOKEN_T(STRING_CONST)  \
        TOKEN_T(PUNCTUATION)  \
        TOKEN_T(IDENTIFIER)  \
        TOKEN_T(COMMENT)  \
        TOKEN_T(MULTILINE_COMMENT)  \
        TOKEN_T(NESTED_COMMENT)  \

#define GENERATE_ENUM(ENUM) ENUM,
#define GENERATE_STRING(STRING) #STRING,

enum TOKEN_T_ENUM {
    FOREACH_TOKEN_T(GENERATE_ENUM)
};

static const string TOKEN_T_STRING[] = {
    FOREACH_TOKEN_T(GENERATE_STRING)
};

// the alpha token to be passed in the yytext()
typedef struct alpha_token {
    unsigned int line;
    unsigned int token_number;
    string content = "";
    enum TOKEN_T_ENUM token_type;
    struct alpha_token* next;

} *alpha_token_t;

extern alpha_token_t head;

#endif