// define ansi escape codes to support colorful output
#define ANSI_COLOR_RED     "\x1b[31m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_RESET   "\x1b[0m"

#include "../parser/parser.h"
//#define YY_DECL int alpha_yylex(alpha_token_t token_param)

void print_token(enum TOKEN_T_ENUM tokentype, alpha_token_t tok);