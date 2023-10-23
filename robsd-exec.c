#include "config.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "libks/arena.h"

#include "conf.h"
#include "step-exec.h"

static void	usage(void) __attribute__((__noreturn__));

int
main(int argc, char *argv[])
{
	struct arena *eternal, *scratch;
	struct config *config;
	const char *config_mode = NULL;
	const char *config_path = NULL;
	int ch, error;

	while ((ch = getopt(argc, argv, "C:m:")) != -1) {
		switch (ch) {
		case 'C':
			config_path = optarg;
			break;
		case 'm':
			config_mode = optarg;
			break;
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;
	if (argc == 0 || config_mode == NULL)
		usage();

	eternal = arena_alloc(ARENA_FATAL);
	arena_scope(eternal, eternal_scope);
	scratch = arena_alloc(ARENA_FATAL);

	config = config_alloc(config_mode, config_path, &eternal_scope,
	    scratch);
	if (config == NULL || config_parse(config)) {
		error = 1;
		goto out;
	}

	if (pledge("stdio proc exec", NULL) == -1)
		err(1, "pledge");

	error = step_exec(argv);

out:
	arena_free(scratch);
	arena_free(eternal);
	return error;
}

static void
usage(void)
{
	fprintf(stderr, "usage: robsd-exec utility [argument ...]\n");
	exit(1);
}
