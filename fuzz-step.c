#include "config.h"

#include "libks/arena.h"
#include "libks/compiler.h"
#include "libks/fuzzer.h"

#include "step.h"

struct fuzzer_context {
	struct arena	*eternal;
};

static void *
init(int UNUSED(argc), char **UNUSED(argv))
{
	static struct fuzzer_context c;

	c.eternal = arena_alloc("eternal");

	return &c;
}
FUZZER_INIT(init);

static void
teardown(void *userdata)
{
	struct fuzzer_context *c = userdata;

	arena_free(c->eternal);
}
FUZZER_TEARDOWN(teardown);

static void
target(const char *path, void *userdata)
{
	struct fuzzer_context *c = userdata;
	struct step_file *step_file;

	arena_scope(c->eternal, s);

	step_file = steps_parse(path, &s);
	steps_free(step_file);
}
FUZZER_TARGET_FILE(target);
