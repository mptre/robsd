#include "config.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "extern.h"
#include "invocation.h"

static __dead void	usage(void);

int
main(int argc, char *argv[])
{
	struct config *config = NULL;
	struct invocation *iv = NULL;
	const struct variable *va;
	const char *builddir = NULL;
	const char *mode = NULL;
	const char *path = NULL;
	const char *p;
	int error = 0;
	int skip_builddir = 0;
	int ch;

	if (pledge("stdio rpath inet route", NULL) == -1)
		err(1, "pledge");

	while ((ch = getopt(argc, argv, "Bf:m:")) != -1) {
		switch (ch) {
		case 'B':
			skip_builddir = 1;
			break;
		case 'f':
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

	config = config_alloc(mode, path);
	if (config == NULL) {
		error = 1;
		goto out;
	}
	if (config_parse(config)) {
		error = 1;
		goto out;
	}
	if (skip_builddir && (va = config_find(config, "builddir")) != NULL)
		builddir = variable_get_value(va)->str;

	if (pledge("stdio rpath", NULL) == -1)
		err(1, "pledge");

	iv = invocation_alloc(config);
	if (iv == NULL) {
		error = 1;
		goto out;
	}
	while ((p = invocation_walk(iv)) != NULL) {
		if (builddir != NULL && strcmp(p, builddir) == 0)
			continue;
		printf("%s\n", p);
	}

out:
	invocation_free(iv);
	config_free(config);
	return error;
}

static __dead void
usage(void)
{
	fprintf(stderr, "usage: robsd-ls -m mode [-B] [-f path]\n");
	exit(1);
}
