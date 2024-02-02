#include <limits.h>	/* PATH_MAX */

#define INVOCATION_SORT_ASC	0x00000001u
#define INVOCATION_SORT_DESC	0x00000002u

struct arena;
struct arena_scope;

struct invocation_entry {
	char path[PATH_MAX];
	char basename[NAME_MAX + 1];
};

struct invocation_state		*invocation_alloc(const char *, const char *,
    struct arena_scope *, unsigned int);
struct invocation_state		*invocation_find(const char *, const char *,
    struct arena_scope *);
void				 invocation_free(struct invocation_state *);
const struct invocation_entry	*invocation_walk(struct invocation_state *);

int	invocation_has_tag(const char *, const char *, struct arena *);
