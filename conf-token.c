#include "conf-token.h"

#include "config.h"

#include <err.h>

#include "libks/arena.h"
#include "libks/map.h"

struct token_type_lookup {
	MAP(const char, *, enum token_type)	token_types;
};

static void
token_type_lookup_insert(struct token_type_lookup *lookup, const char *key,
    enum token_type val)
{
	if (MAP_INSERT_VALUE(lookup->token_types, key, val) == NULL)
		err(1, NULL);
}

struct token_type_lookup *
token_type_lookup_alloc(enum robsd_mode mode, struct arena_scope *s)
{
	struct token_type_lookup *lookup;

	lookup = arena_calloc(s, 1, sizeof(*lookup));
	if (MAP_INIT(lookup->token_types))
		err(1, NULL);
#define OP(name, key, m) do {						\
	if ((key)[0] != '\0' && ((m) == 0 || (m) == mode))		\
		token_type_lookup_insert(lookup, (key), TOKEN_ ## name);\
} while (0);
	FOR_TOKEN_TYPES(OP)
#undef OP

	return lookup;
}

void
token_type_lookup_free(struct token_type_lookup *lookup)
{
	MAP_FREE(lookup->token_types);
}

enum token_type
token_type_lookup(const struct token_type_lookup *lookup, const char *str,
    enum token_type fallback)
{
	const enum token_type *token_type;

	token_type = MAP_FIND(lookup->token_types, str);
	if (token_type == NULL)
		return fallback;
	return *token_type;
}

const char *
token_type_str(enum token_type token_type)
{
	switch (token_type) {
#define OP(name, ...) case TOKEN_ ## name: return #name;
	FOR_TOKEN_TYPES(OP)
#undef OP
	}
	return "UNKNOWN";
}
