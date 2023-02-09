#include "config.h"

#include <err.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "conf.h"
#include "vector.h"

static __dead void	usage(void);

int
main(int argc, char *argv[])
{
	VECTOR(const char *) vars;
	struct config *config = NULL;
	const char *mode = NULL;
	const char *path = NULL;
	size_t i;
	int dointerpolate = 0;
	int error = 0;
	int ch;

	if (pledge("stdio rpath inet getpw route", NULL) == -1)
		err(1, "pledge");

	if (VECTOR_INIT(vars) == NULL)
		err(1, NULL);

	while ((ch = getopt(argc, argv, "f:m:v:")) != -1) {
		switch (ch) {
		case 'f':
			path = optarg;
			break;
		case 'm':
			mode = optarg;
			break;
		case 'v':
			*VECTOR_ALLOC(vars) = optarg;
			break;
		default:
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

	config = config_alloc(mode, path);
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

	if (dointerpolate)
		error = config_interpolate(config);

out:
	config_free(config);
	VECTOR_FREE(vars);
	return error;
}

static __dead void
usage(void)
{
	fprintf(stderr, "usage: robsd-config -m mode [-f file] [-v var=val] "
	    "[-]\n");
	exit(1);
}
