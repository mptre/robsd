#include "config.h"

#include <string.h>

#include "libks/arena.h"
#include "libks/fuzzer.h"

#include "conf.h"
#include "mode.h"

struct fuzzer_context {
	const char	*mode;
	struct arena	*eternal;
	struct arena	*scratch;
};

static void *
init(int argc, char *argv[])
{
	static struct fuzzer_context c;

	c.mode = robsd_mode_str(ROBSD);
	for (int i = 0; i < argc; i++) {
		if (strcmp(argv[i], "--mode") == 0 && i + 1 < argc) {
			enum robsd_mode mode;

			if (robsd_mode_parse(argv[i + 1], &mode))
				__builtin_trap();
			c.mode = argv[i + 1];
		}
	}

	c.eternal = arena_alloc();
	c.scratch = arena_alloc();

	return &c;
}
FUZZER_INIT(init);

static void
teardown(void *userdata)
{
	struct fuzzer_context *c = userdata;

	arena_free(c->scratch);
	arena_free(c->eternal);
}
FUZZER_TEARDOWN(teardown);

static void
target(const char *path, void *userdata)
{
	struct fuzzer_context *c = userdata;
	struct config *config;

	arena_scope(c->eternal, eternal_scope);

	config = config_alloc(c->mode, path, &eternal_scope, c->scratch);
	if (config == NULL)
		__builtin_trap();
	config_parse(config);
	config_free(config);
}
FUZZER_TARGET_FILE(target);
