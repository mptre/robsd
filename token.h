#include <sys/queue.h>

struct token {
	int			tk_type;
	int			tk_lno;

	union {
		char	*tk_str;
		int64_t	 tk_int;
	};

	TAILQ_ENTRY(token)	tk_entry;
};

void	token_free(struct token *);
