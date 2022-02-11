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
	struct config *config;
	const struct string *st;
	const struct string_list *strings;
	const struct variable *va;
	char **args = NULL;
	const char *path = NULL;
	unsigned int i = 0;
	unsigned int nargs;
	int error = 0;
	int verbose = 0;
	int ch;

	if (pledge("stdio rpath exec getpw", NULL) == -1)
		err(1, "pledge");

	config = config_alloc();

	while ((ch = getopt(argc, argv, "Vf:v:")) != -1) {
		switch (ch) {
		case 'V':
			verbose++;
			break;

		case 'f': {
			int n;

			n = snprintf(bufpath, sizeof(bufpath), "%s", optarg);
			if (n < 0 || n >= (ssize_t)sizeof(bufpath))
				errc(1, ENAMETOOLONG, "%s", optarg);
			path = bufpath;
			break;
		}

		case 'v': {
			char *name, *val;

			val = strchr(optarg, '=');
			if (val == NULL)
				errx(1, "missing variable separator: %s",
				    optarg);
			name = strndup(optarg, val - optarg);
			if (name == NULL)
				err(1, NULL);
			val++;	/* consume '=' */
			if (config_append_string(config, name, val))
				errx(1, "variable '%s' cannot be defined",
				    name);
			free(name);
			break;
		}

		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;
	if (argc > 0)
		usage();

	if (config_parse(config, path)) {
		error = 1;
		goto out;
	}

	if (config_validate(config)) {
		error = 1;
		goto out;
	}

	if (pledge("stdio exec", NULL) == -1)
		err(1, "pledge");

	va = config_find(config, "hook");
	if (va == NULL)
		goto out;
	strings = variable_list(va);
	nargs = strings_len(strings);
	if (nargs == 0)
		goto out;

	args = reallocarray(NULL, nargs + 1, sizeof(*args));
	if (args == NULL)
		err(1, NULL);
	args[nargs] = NULL;
	TAILQ_FOREACH(st, strings, st_entry) {
		char *arg;

		arg = config_interpolate_str(config, st->st_val, 0);
		if (arg == NULL) {
			error = 1;
			goto out;
		}
		args[i++] = arg;
	}

	if (verbose > 0) {
		fprintf(stdout, "%s: exec", getprogname());
		for (i = 0; i < nargs; i++)
			fprintf(stdout, " \"%s\"", args[i]);
		fprintf(stdout, "\n");
		fflush(stdout);
	}

	if (execvp(args[0], args) == -1) {
		warn("%s", args[0]);
		error = 1;
	}

out:
	free(args);
	config_free(config);
	return error;
}

static __dead void
usage(void)
{
	fprintf(stderr, "usage: robsd-hook [-v var=val] [-f file]\n");
	exit(1);
}
