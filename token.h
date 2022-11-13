#include <sys/queue.h>

#include <stdint.h>	/* int64_t */

struct token {
	int			 tk_type;
	int			 tk_lno;

	char			*tk_str;
	int64_t			 tk_int;

	TAILQ_ENTRY(token)	 tk_entry;
};

struct token	*token_alloc(int);
void		 token_free(struct token *);
