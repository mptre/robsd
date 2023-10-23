#include "config.h"

#include <stddef.h>

#include "libks/arena.h"

#include "conf.h"

int
main(int argc, char *argv[])
{
	struct arena *eternal, *scratch;
	struct config *config = NULL;
	const char *mode = "robsd";
	int error;

	if (argc == 2)
		mode = argv[1];

	eternal = arena_alloc(ARENA_FATAL);
	arena_scope(eternal, eternal_scope);
	scratch = arena_alloc(ARENA_FATAL);

	config = config_alloc(mode, "/dev/stdin", &eternal_scope, scratch);
	if (config == NULL)
		return 1;
	error = config_parse(config);
	config_free(config);
	arena_free(scratch);
	arena_free(eternal);
	return error;
}
