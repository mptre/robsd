#include "config.h"

#include <err.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "extern.h"
#include "vector.h"

static __dead void	usage(void);

int
main(int argc, char *argv[])
{
	struct config *config = NULL;
	const struct variable *va;
	const union variable_value *val;
	char **args = NULL;
	unsigned int i = 0;
	unsigned int nargs;
	int error = 0;
	int verbose = 0;
	int ch;

	if (pledge("stdio rpath exec getpw", NULL) == -1)
		err(1, "pledge");

	while ((ch = getopt(argc, argv, "Vf:m:v:")) != -1) {
		switch (ch) {
		case 'V':
			verbose++;
			break;
		case 'f':
			if (config == NULL)
				usage();
			config_set_path(config, optarg);
			break;
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
	if (argc > 0 || config == NULL)
		usage();

	if (config_parse(config)) {
		error = 1;
		goto out;
	}

	if (pledge("stdio exec", NULL) == -1)
		err(1, "pledge");

	va = config_find(config, "hook");
	if (va == NULL)
		goto out;
	val = variable_get_value(va);
	nargs = VECTOR_LENGTH(val->list);
	if (nargs == 0)
		goto out;

	args = reallocarray(NULL, nargs + 1, sizeof(*args));
	if (args == NULL)
		err(1, NULL);
	args[nargs] = NULL;
	for (i = 0; i < VECTOR_LENGTH(val->list); i++) {
		const char *str = val->list[i];
		char *arg;

		arg = config_interpolate_str(config, str, NULL, 0);
		if (arg == NULL) {
			error = 1;
			goto out;
		}
		args[i] = arg;
	}

	if (verbose > 0) {
		fprintf(stdout, "robsd-hook: exec");
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
	fprintf(stderr, "usage: robsd-hook -m mode [-f file] [-v var=val]\n");
	exit(1);
}
