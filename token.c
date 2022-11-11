#include "token.h"

#include <err.h>
#include <stdlib.h>

struct token *
token_alloc(int type)
{
	struct token *tk;

	tk = calloc(1, sizeof(*tk));
	if (tk == NULL)
		err(1, NULL);
	tk->tk_type = type;
	return tk;
}

void
token_free(struct token *tk)
{
	if (tk == NULL)
		return;

	switch (tk->tk_type) {
	case TOKEN_KEYWORD:
	case TOKEN_STRING:
		free(tk->tk_str);
		break;
	case TOKEN_UNKNOWN:
	case TOKEN_LBRACE:
	case TOKEN_RBRACE:
	case TOKEN_ENV:
	case TOKEN_OBJ:
	case TOKEN_PACKAGES:
	case TOKEN_QUIET:
	case TOKEN_ROOT:
	case TOKEN_TARGET:
	case TOKEN_BOOLEAN:
	case TOKEN_INTEGER:
		break;
	}
	free(tk);
}

const char *
token_serialize(const struct token *tk)
{
	enum token_type type = tk->tk_type;

	switch (type) {
	case TOKEN_UNKNOWN:
		break;
	case TOKEN_LBRACE:
		return "LBRACE";
	case TOKEN_RBRACE:
		return "RBRACE";
	case TOKEN_KEYWORD:
		return "KEYWORD";
	case TOKEN_ENV:
		return "ENV";
	case TOKEN_OBJ:
		return "OBJ";
	case TOKEN_PACKAGES:
		return "PACKAGES";
	case TOKEN_QUIET:
		return "QUIET";
	case TOKEN_ROOT:
		return "ROOT";
	case TOKEN_TARGET:
		return "TARGET";
	case TOKEN_BOOLEAN:
		return "BOOLEAN";
	case TOKEN_INTEGER:
		return "INTEGER";
	case TOKEN_STRING:
		return "STRING";
	}
	return "UNKNOWN";
}
