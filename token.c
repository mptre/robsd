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

	free(tk->tk_str);
	free(tk);
}
