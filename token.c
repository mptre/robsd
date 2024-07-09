#include "token.h"

#include "config.h"

#include <stdlib.h>

#include "alloc.h"

void
token_free(struct token *tk)
{
	if (tk == NULL)
		return;
	free(tk);
}
