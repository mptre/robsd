#include "config.h"

#include <err.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "conf.h"
#include "interpolate.h"
#include "vector.h"

static __dead void	usage(void);

static int	hook_to_argv(struct config *, char ***);

int
main(int argc, char *argv[])
{
	VECTOR(const char *) vars;
	VECTOR(char *) args = NULL;
	struct config *config = NULL;
	const char *mode = NULL;
	const char *path = NULL;
	size_t i;
	int error = 0;
	int verbose = 0;
	int ch;

	if (pledge("stdio rpath inet exec getpw route", NULL) == -1)
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

	switch (hook_to_argv(config, &args)) {
	case -1:
		error = 1;
		goto out;
	case 0:
		goto out;
	}

	if (verbose > 0) {
		fprintf(stdout, "robsd-hook: exec");
		for (i = 0; i < VECTOR_LENGTH(args); i++)
			fprintf(stdout, " \"%s\"", args[i]);
		fprintf(stdout, "\n");
		fflush(stdout);
	}

	if (execvp(args[0], args) == -1) {
		warn("%s", args[0]);
		error = 1;
	}

out:
	VECTOR_FREE(args);
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

static int
hook_to_argv(struct config *config, char ***out)
{
	VECTOR(char *) args;
	const struct variable *va;
	const union variable_value *val;
	size_t i, nargs;
	int error = 0;

	va = config_find(config, "hook");
	if (va == NULL)
		return 0;
	val = variable_get_value(va);
	nargs = VECTOR_LENGTH(val->list);
	if (nargs == 0)
		return 0;

	if (VECTOR_INIT(args) == NULL)
		err(1, NULL);
	if (VECTOR_RESERVE(args, nargs + 1) == NULL)
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
			break;
		}
		*VECTOR_ALLOC(args) = arg;
	}

	if (error) {
		VECTOR_FREE(args);
		return -1;
	}
	*out = args;
	return 1;
}
