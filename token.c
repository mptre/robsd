#include "token.h"

#include <stdlib.h>

#include "alloc.h"

struct token *
token_alloc(int type)
{
	struct token *tk;

	tk = ecalloc(1, sizeof(*tk));
	tk->tk_type = type;
	return tk;
}

void
token_free(struct token *tk)
{
	if (tk == NULL)
		return;

	free(tk->tk_str);
	free(tk);
}
