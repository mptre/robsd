#include "conf-token.h"

#include "config.h"

const char *
token_type_str(enum token_type token_type)
{
	switch (token_type) {
#define OP(name, ...) case TOKEN_ ## name: return #name;
	FOR_TOKEN_TYPES(OP)
#undef OP
	}
}
