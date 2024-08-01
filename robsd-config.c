#include "config.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "libks/arena.h"
#include "libks/vector.h"

#include "conf.h"

static void	usage(void)
	__attribute__((__noreturn__));

int
main(int argc, char *argv[])
{
	VECTOR(const char *) vars;
	struct arena *eternal, *scratch;
	struct config *config = NULL;
	const char *mode = NULL;
	const char *path = NULL;
	size_t i;
	int dointerpolate = 0;
	int error = 0;
	int ch;

	if (pledge("stdio rpath inet getpw route", NULL) == -1)
		err(1, "pledge");

	if (VECTOR_INIT(vars))
		err(1, NULL);

	while ((ch = getopt(argc, argv, "C:m:v:")) != -1) {
		switch (ch) {
		case 'C':
			path = optarg;
			break;
		case 'm':
			mode = optarg;
			break;
		case 'v': {
			const char **dst;

			dst = VECTOR_ALLOC(vars);
			if (dst == NULL)
				err(1, NULL);
			*dst = optarg;
			break;
		}
		default:
			VECTOR_FREE(vars);
			usage();
		}
	}
	argc -= optind;
	argv += optind;
	if (argc > 1 || mode == NULL)
		usage();
	if (argc == 1) {
		if (strcmp(argv[0], "-") == 0)
			dointerpolate = 1;
		else
			usage();
	}

	eternal = arena_alloc();
	arena_scope(eternal, eternal_scope);
	scratch = arena_alloc();

	config = config_alloc(mode, path, &eternal_scope, scratch);
	if (config == NULL) {
		error = 1;
		goto out;
	}
	if (config_parse(config)) {
		error = 1;
		goto out;
	}

	if (pledge("stdio rpath inet route", NULL) == -1)
		err(1, "pledge");

	for (i = 0; i < VECTOR_LENGTH(vars); i++) {
		if (config_append_var(config, vars[i])) {
			error = 1;
			goto out;
		}
	}

	if (dointerpolate) {
		const char *str;

		str = config_interpolate_file(config, "/dev/stdin");
		if (str != NULL)
			printf("%s", str);
		else
			error = 1;
	}

out:
	config_free(config);
	arena_free(scratch);
	arena_free(eternal);
	VECTOR_FREE(vars);
	return error;
}

static void
usage(void)
{
	fprintf(stderr, "usage: robsd-config -m mode [-v var=val] "
	    "[-]\n");
	exit(1);
}
