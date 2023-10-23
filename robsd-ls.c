#include "config.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "libks/arena.h"

#include "conf.h"
#include "invocation.h"

static void	usage(void) __attribute__((__noreturn__));

int
main(int argc, char *argv[])
{
	struct arena *arena, *scratch;
	struct config *config = NULL;
	struct invocation_state *is = NULL;
	const struct invocation_entry *entry;
	const char *builddir = NULL;
	const char *mode = NULL;
	const char *path = NULL;
	const char *keepdir, *robsddir;
	int error = 0;
	int skip_builddir = 0;
	int ch;

	if (pledge("stdio rpath", NULL) == -1)
		err(1, "pledge");

	while ((ch = getopt(argc, argv, "BC:m:")) != -1) {
		switch (ch) {
		case 'B':
			skip_builddir = 1;
			break;
		case 'C':
			path = optarg;
			break;
		case 'm':
			mode = optarg;
			break;
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;
	if (argc > 0 || mode == NULL)
		usage();

	arena = arena_alloc(ARENA_FATAL);
	arena_scope(arena, eternal);
	scratch = arena_alloc(ARENA_FATAL);

	config = config_alloc(mode, path, &eternal, scratch);
	if (config == NULL) {
		error = 1;
		goto out;
	}
	if (config_parse(config)) {
		error = 1;
		goto out;
	}
	if (skip_builddir)
		builddir = config_value(config, "builddir", str, NULL);

	robsddir = config_interpolate_str(config, "${robsddir}");
	if (robsddir == NULL) {
		error = 1;
		goto out;
	}
	keepdir = config_interpolate_str(config, "${keep-dir}");
	if (keepdir == NULL) {
		error = 1;
		goto out;
	}
	is = invocation_alloc(robsddir, keepdir, INVOCATION_SORT_DESC);
	if (is == NULL) {
		error = 1;
		goto out;
	}
	while ((entry = invocation_walk(is)) != NULL) {
		if (builddir != NULL && strcmp(entry->path, builddir) == 0)
			continue;
		printf("%s\n", entry->path);
	}

out:
	invocation_free(is);
	config_free(config);
	arena_free(scratch);
	arena_free(arena);
	return error;
}

static void
usage(void)
{
	fprintf(stderr, "usage: robsd-ls -m mode [-B]\n");
	exit(1);
}
