#include "config.h"

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
	struct config *config = NULL;
	int dointerpolate = 0;
	int error = 0;
	int ch;

	if (pledge("stdio rpath inet getpw route", NULL) == -1)
		err(1, "pledge");

	while ((ch = getopt(argc, argv, "f:m:v:")) != -1) {
		switch (ch) {
		case 'f': {
			int n;

			if (config == NULL)
				usage();

			n = snprintf(bufpath, sizeof(bufpath), "%s", optarg);
			if (n < 0 || n >= (ssize_t)sizeof(bufpath)) {
				warnc(ENAMETOOLONG, "%s", optarg);
				error = 1;
				goto out;
			}
			path = bufpath;
			break;
		}

		case 'm':
			config = config_alloc(optarg);
			if (config == NULL) {
				error = 1;
				goto out;
			}
			break;

		case 'v':
			if (config == NULL ||
			    config_append_var(config, optarg)) {
				error = 1;
				goto out;
			}
			break;

		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;
	if (argc > 1 || config == NULL)
		usage();
	if (argc == 1) {
		if (strcmp(argv[0], "-") == 0)
			dointerpolate = 1;
		else
			usage();
	}

	if (config_parse(config, path) || config_validate(config)) {
		error = 1;
		goto out;
	}

	if (pledge("stdio rpath inet route", NULL) == -1)
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
	fprintf(stderr, "usage: robsd-config -m mode [-f file] [-v var=val]"
	    "[-]\n");
	exit(1);
}
