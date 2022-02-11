#include <err.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "extern.h"

static __dead void	usage(void);

int
main(int argc, char *argv[])
{
	char bufpath[PATH_MAX];
	const char *path = NULL;
	struct config *config;
	int dointerpolate = 0;
	int error = 0;
	int ch;

	if (pledge("stdio rpath getpw", NULL) == -1)
		err(1, "pledge");

	config = config_alloc();

	while ((ch = getopt(argc, argv, "b:f:")) != -1) {
		switch (ch) {
		case 'b':
			if (config_set_builddir(config, optarg)) {
				error = 1;
				goto out;
			}
			break;

		case 'f': {
			int n;

			n = snprintf(bufpath, sizeof(bufpath), "%s", optarg);
			if (n < 0 || n >= (ssize_t)sizeof(bufpath)) {
				warnc(ENAMETOOLONG, "%s", optarg);
				error = 1;
				goto out;
			}
			path = bufpath;
			break;
		}

		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;
	if (argc > 1)
		usage();
	if (argc == 1) {
		if (strcmp(argv[0], "-") == 0)
			dointerpolate = 1;
		else
			usage();
	}

	if (config_parse(config, path)) {
		error = 1;
		goto out;
	}

	if (config_validate(config)) {
		error = 1;
		goto out;
	}

	if (pledge("stdio", NULL) == -1)
		err(1, "pledge");

	if (dointerpolate)
		error = config_interpolate(config);

out:
	config_free(config);
	return error;
}

static __dead void
usage(void)
{
	fprintf(stderr, "usage: robsd-config [-n] [-b build-dir] [-f file] "
	    "[-]\n");
	exit(1);
}
