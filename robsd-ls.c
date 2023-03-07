#include "config.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "conf.h"
#include "invocation.h"

static void	usage(void)
	__attribute__((__noreturn__));

int
main(int argc, char *argv[])
{
	struct config *config = NULL;
	struct invocation_state *is = NULL;
	const struct variable *va;
	const char *builddir = NULL;
	const char *mode = NULL;
	const char *path = NULL;
	const char *keepdir, *p, *robsddir;
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
	if (skip_builddir) {
		va = config_find(config, "builddir");
		if (va != NULL)
			builddir = variable_get_value(va)->str;
	}

	if (pledge("stdio rpath", NULL) == -1)
		err(1, "pledge");

	va = config_find(config, "robsddir");
	robsddir = variable_get_value(va)->str;
	va = config_find(config, "keep-dir");
	keepdir = variable_get_value(va)->str;
	is = invocation_alloc(robsddir, keepdir);
	if (is == NULL) {
		error = 1;
		goto out;
	}
	while ((p = invocation_walk(is)) != NULL) {
		if (builddir != NULL && strcmp(p, builddir) == 0)
			continue;
		printf("%s\n", p);
	}

out:
	invocation_free(is);
	config_free(config);
	return error;
}

static void
usage(void)
{
	fprintf(stderr, "usage: robsd-ls -m mode [-B] [-f path]\n");
	exit(1);
}
