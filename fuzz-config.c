#include "config.h"

#include "libks/arena.h"
#include "libks/fuzzer.h"

#include "conf.h"

struct context {
	struct arena	*eternal;
	struct arena	*scratch;
};

static void *
init(void)
{
	static struct context c;

	c.eternal = arena_alloc(ARENA_FATAL);
	c.scratch = arena_alloc(ARENA_FATAL);
	return &c;
}
FUZZER_INIT(init);

static void
teardown(void *userdata)
{
	struct context *c = userdata;

	arena_free(c->scratch);
	arena_free(c->eternal);
}
FUZZER_TEARDOWN(teardown);

static void
target(const char *path, void *userdata)
{
	struct context *c = userdata;
	struct config *config = NULL;
	const char *mode = "robsd";

	arena_scope(c->eternal, eternal_scope);

	config = config_alloc(mode, path, &eternal_scope, c->scratch);
	if (config == NULL)
		__builtin_trap();
	config_parse(config);
	config_free(config);
}
FUZZER_TARGET_FILE(target);
