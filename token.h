#include <sys/queue.h>

#include <stdint.h>	/* int64_t */

enum token_type {
	/* sentinels */
	TOKEN_UNKNOWN,

	/* literals */
	TOKEN_LBRACE,
	TOKEN_RBRACE,

	/* keywords */
	TOKEN_KEYWORD,
	TOKEN_ENV,
	TOKEN_OBJ,
	TOKEN_PACKAGES,
	TOKEN_QUIET,
	TOKEN_ROOT,
	TOKEN_TARGET,

	/* types */
	TOKEN_BOOLEAN,
	TOKEN_INTEGER,
	TOKEN_STRING,
};

struct token {
	int			tk_type;
	int			tk_lno;

	union {
		char	*tk_str;
		int64_t	 tk_int;
	};

	TAILQ_ENTRY(token)	tk_entry;
};

struct token	*token_alloc(int);
void		 token_free(struct token *);
const char	*token_serialize(const struct token *);
