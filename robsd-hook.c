#include "config.h"

#include <err.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "extern.h"
#include "interpolate.h"
#include "vector.h"

static __dead void	usage(void);

int
main(int argc, char *argv[])
{
	VECTOR(const char *) vars;
	struct config *config = NULL;
	const struct variable *va;
	const union variable_value *val;
	char **args = NULL;
	const char *mode = NULL;
	const char *path = NULL;
	unsigned int i = 0;
	unsigned int nargs;
	int error = 0;
	int verbose = 0;
	int ch;

	if (pledge("stdio rpath exec getpw", NULL) == -1)
		err(1, "pledge");

	if (VECTOR_INIT(vars) == NULL)
		err(1, NULL);

	while ((ch = getopt(argc, argv, "Vf:m:v:")) != -1) {
		switch (ch) {
		case 'V':
			verbose++;
			break;
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

	if (pledge("stdio exec", NULL) == -1)
		err(1, "pledge");

	for (i = 0; i < VECTOR_LENGTH(vars); i++) {
		if (config_append_var(config, vars[i])) {
			error = 1;
			goto out;
		}
	}

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

		arg = interpolate_str(str, &(struct interpolate_arg){
			.lookup	= config_interpolate_lookup,
			.arg	= config,
		});
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
	VECTOR_FREE(vars);
	return error;
}

static __dead void
usage(void)
{
	fprintf(stderr, "usage: robsd-hook -m mode [-f file] [-v var=val]\n");
	exit(1);
}
