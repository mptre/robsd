#include <stdint.h>	/* int64_t */

#include "libks/list.h"

LIST(token_list, token);

struct token {
	int			 tk_type;
	int			 tk_lno;

	char			*tk_str;
	int64_t			 tk_int;

	LIST_ENTRY(token_list, token);
};
