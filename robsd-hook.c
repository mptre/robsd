#include "config.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "libks/arena.h"
#include "libks/vector.h"

#include "conf.h"
#include "interpolate.h"
#include "variable-value.h"

static void	usage(void) __attribute__((noreturn));

static int	hook_to_argv(struct config *, struct arena_scope *,
    struct arena *, char ***);

int
main(int argc, char *argv[])
{
	VECTOR(const char *) vars;
	VECTOR(char *) args = NULL;
	struct arena *eternal, *scratch;
	struct config *config = NULL;
	const char *mode = NULL;
	const char *path = NULL;
	size_t i;
	int error = 0;
	int verbose = 0;
	int ch;

	if (pledge("stdio rpath inet exec getpw route", NULL) == -1)
		err(1, "pledge");

	if (VECTOR_INIT(vars))
		err(1, NULL);

	while ((ch = getopt(argc, argv, "C:Vm:v:")) != -1) {
		switch (ch) {
		case 'C':
			path = optarg;
			break;
		case 'V':
			verbose++;
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
	if (argc > 0 || mode == NULL)
		usage();

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

	for (i = 0; i < VECTOR_LENGTH(vars); i++) {
		if (config_append_var(config, vars[i])) {
			error = 1;
			goto out;
		}
	}

	switch (hook_to_argv(config, &eternal_scope, scratch, &args)) {
	case -1:
		error = 1;
		goto out;
	case 0:
		goto out;
	}

	if (pledge("stdio exec", NULL) == -1)
		err(1, "pledge");

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
	arena_free(scratch);
	arena_free(eternal);
	VECTOR_FREE(vars);
	return error;
}

static void
usage(void)
{
	fprintf(stderr, "usage: robsd-hook -m mode [-v var=val]\n");
	exit(1);
}

static int
hook_to_argv(struct config *config, struct arena_scope *eternal,
    struct arena *scratch, char ***out)
{
	VECTOR(char *) args;
	VECTOR(char *) hook;
	size_t i, nargs;
	int error = 0;

	hook = config_value(config, "hook", list, NULL);
	if (hook == NULL)
		return 0;
	nargs = VECTOR_LENGTH(hook);
	if (nargs == 0)
		return 0;

	if (VECTOR_INIT(args))
		err(1, NULL);
	if (VECTOR_RESERVE(args, nargs + 1))
		err(1, NULL);
	args[nargs] = NULL;
	for (i = 0; i < VECTOR_LENGTH(hook); i++) {
		char **dst;
		const char *str = hook[i];
		const char *arg;

		arg = interpolate_str(str, &(struct interpolate_arg){
		    .lookup	= config_interpolate_lookup,
		    .arg	= config,
		    .eternal	= eternal,
		    .scratch	= scratch,
		});
		if (arg == NULL) {
			error = 1;
			break;
		}
		dst = VECTOR_ALLOC(args);
		if (dst == NULL)
			err(1, NULL);
		*dst = (char *)arg;
	}

	if (error) {
		VECTOR_FREE(args);
		return -1;
	}
	*out = args;
	return 1;
}
