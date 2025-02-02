#include "config.h"

#include <err.h>
#include <limits.h>	/* PATH_MAX */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "libks/arena-buffer.h"
#include "libks/arena.h"
#include "libks/buffer.h"
#include "libks/vector.h"

#include "conf.h"
#include "interpolate.h"
#include "step.h"

enum step_action {
	ACTION_INVALID,
	ACTION_READ,
	ACTION_WRITE,
	ACTION_LIST,
};

enum step_action_error {
	ACTION_ERROR_NONE = 0,
	ACTION_ERROR_FATAL = 1,
	ACTION_ERROR_USAGE = 2,
};

struct step_context {
	const char		*path;
	struct arena_scope	*eternal;
	struct arena		*scratch;
	struct step_file	*step_file;
};

static void	usage(void) __attribute__((noreturn));

static int	steps_read(struct step_context *, int, char **);
static int	action_write(struct step_context *, int, char **);
static int	steps_list(struct step_context *, int, char **);

static int
parse_id(const char *str, int *id)
{
	const char *errstr;
	long long rv;

	rv = strtonum(str, -INT_MAX, INT_MAX, &errstr);
	if (errstr != NULL) {
		warnx("id %s %s", str, errstr);
		return 1;
	}
	*id = rv;
	return 0;
}

int
main(int argc, char *argv[])
{
	struct step_context c = {0};
	struct arena *eternal;
	enum step_action action = 0;
	int error = 0;
	int ch;

	if (pledge("stdio rpath wpath cpath flock unveil", NULL) == -1)
		err(1, "pledge");

	opterr = 0;
	while ((ch = getopt(argc, argv, "LRWf:")) != -1) {
		switch (ch) {
		case 'L':
			action = ACTION_LIST;
			break;
		case 'R':
			action = ACTION_READ;
			break;
		case 'W':
			action = ACTION_WRITE;
			break;
		case 'f':
			c.path = optarg;
			break;
		default:
			goto done;
		}
	}
done:
	if (optind >= 2) {
		argc -= optind - 2;
		argv += optind - 2;
	}
	if (action == 0)
		usage();

	eternal = arena_alloc();
	arena_scope(eternal, eternal_scope);
	c.eternal = &eternal_scope;
	c.scratch = arena_alloc();

	/* Pave the way for action specific options. */
	opterr = 1;
	optind = 0;

	switch (action) {
	case ACTION_READ:
		if (c.path == NULL)
			usage();
		if (unveil("/dev/stdin", "r") == -1)
			err(1, "unveil: /dev/stdin");
		if (unveil(c.path, "r") == -1)
			err(1, "unveil: %s", c.path);
		if (pledge("stdio rpath flock", NULL) == -1)
			err(1, "pledge");
		c.step_file = steps_parse(c.path, &eternal_scope);
		if (c.step_file == NULL) {
			error = 1;
			goto out;
		}
		error = steps_read(&c, argc, argv);
		break;
	case ACTION_WRITE:
		if (c.path == NULL)
			usage();
		if (unveil(c.path, "rwc") == -1)
			err(1, "unveil: %s", c.path);
		if (pledge("stdio rpath wpath cpath flock", NULL) == -1)
			err(1, "pledge");
		c.step_file = steps_parse(c.path, &eternal_scope);
		if (c.step_file == NULL) {
			error = 1;
			goto out;
		}
		error = action_write(&c, argc, argv);
		break;
	case ACTION_LIST:
		if (pledge("stdio rpath", NULL) == -1)
			err(1, "pledge");
		error = steps_list(&c, argc, argv);
		break;
	case ACTION_INVALID:
		__builtin_trap();
		/* UNREACHABLE */
	}

out:
	steps_free(c.step_file);
	arena_free(c.scratch);
	arena_free(eternal);
	if (error == ACTION_ERROR_USAGE)
		usage();
	return error;
}

static void
usage(void)
{
	fprintf(stderr,
	    "usage: robsd-step -R -f path [-i id] [-n name]\n"
	    "       robsd-step -W -f path -i id -- key=val ...\n"
	    "       robsd-step -L -m mode\n");
	exit(1);
}

static int
steps_read(struct step_context *c, int argc, char **argv)
{
	struct step *st, *steps;
	const char *name = NULL;
	const char *str;
	size_t nsteps;
	int error = ACTION_ERROR_NONE;
	int id = 0;
	int ch;

	while ((ch = getopt(argc, argv, "i:n:")) != -1) {
		switch (ch) {
		case 'i':
			if (parse_id(optarg, &id))
				return ACTION_ERROR_FATAL;
			break;
		case 'n':
			name = optarg;
			break;
		default:
			return ACTION_ERROR_USAGE;
		}
	}
	argc -= optind;
	argv += optind;
	if (argc > 0)
		return ACTION_ERROR_USAGE;
	if (name != NULL && id != 0) {
		warnx("-i and -n are mutually exclusive");
		return ACTION_ERROR_FATAL;
	}

	steps = steps_get(c->step_file);
	nsteps = VECTOR_LENGTH(steps);
	if (name != NULL) {
		st = steps_find_by_name(steps, name);
		if (st == NULL) {
			warnx("step with name '%s' not found", name);
			return ACTION_ERROR_FATAL;
		}
	} else if (id > 0 && (size_t)id - 1 < nsteps) {
		st = &steps[id - 1];
	} else if (id < 0 && (size_t)-id <= nsteps) {
		st = &steps[(int)nsteps + id];
	} else {
		warnx("step with id %d not found", id);
		return ACTION_ERROR_FATAL;
	}

	str = interpolate_file("/dev/stdin",
	    &(struct interpolate_arg){
		.lookup		= step_interpolate_lookup,
		.arg		= st,
		.eternal	= c->eternal,
		.scratch	= c->scratch,
	});
	if (str != NULL)
		printf("%s", str);
	else
		error = ACTION_ERROR_FATAL;
	return error;
}

static int
action_write(struct step_context *c, int argc, char **argv)
{
	struct step *st;
	int id = 0;
	int doheader = 0;
	int ch;

	while ((ch = getopt(argc, argv, "Hi:")) != -1) {
		switch (ch) {
		case 'H':
			doheader = 1;
			break;
		case 'i':
			if (parse_id(optarg, &id))
				return ACTION_ERROR_FATAL;
			break;
		default:
			return ACTION_ERROR_USAGE;
		}
	}
	argc -= optind;
	argv += optind;
	if (!doheader && (argc == 0 || id == 0))
		return ACTION_ERROR_USAGE;

	if (doheader) {
		struct buffer *bf;

		arena_scope(c->scratch, s);

		bf = arena_buffer_alloc(&s, 1 << 10);
		steps_header(bf);
		buffer_putc(bf, '\0');
		printf("%s", buffer_get_ptr(bf));
		return ACTION_ERROR_NONE;
	}

	st = steps_find_by_id(steps_get(c->step_file), id);
	if (st == NULL) {
		st = steps_alloc(c->step_file);
		if (step_init(c->step_file, st) ||
		    step_set_field_integer(st, "step", id))
			return ACTION_ERROR_FATAL;
	}
	for (; argc > 0; argc--, argv++) {
		if (step_set_keyval(c->step_file, st, *argv, c->scratch))
			return ACTION_ERROR_FATAL;
	}
	return steps_write(c->step_file, c->scratch) ?
	    ACTION_ERROR_FATAL : ACTION_ERROR_NONE;
}

static int
steps_list(struct step_context *c, int argc, char **argv)
{
	struct config *config;
	const char *config_mode = NULL;
	const char *config_path = NULL;
	VECTOR(const struct config_step) steps;
	size_t i;
	unsigned int offset = 1;
	int error = ACTION_ERROR_NONE;
	int ch;

	while ((ch = getopt(argc, argv, "C:m:o:")) != -1) {
		switch (ch) {
		case 'C':
			config_path = optarg;
			break;
		case 'm':
			config_mode = optarg;
			break;
		case 'o': {
			const char *errstr;
			long long num;

			num = strtonum(optarg, 1, INT_MAX, &errstr);
			if (num == 0) {
				warnx("offset %s %s", optarg, errstr);
				return ACTION_ERROR_FATAL;
			}
			offset = (unsigned int)num;
			break;
		}
		default:
			return ACTION_ERROR_USAGE;
		}
	}
	argc -= optind;
	argv += optind;
	if (argc != 0 || config_mode == NULL)
		return ACTION_ERROR_USAGE;

	arena_scope(c->scratch, s);

	config = config_alloc(config_mode, config_path, c->eternal, c->scratch);
	if (config == NULL)
		return ACTION_ERROR_FATAL;
	if (config_parse(config)) {
		error = ACTION_ERROR_FATAL;
		goto out;
	}

	steps = config_get_steps(config, 0, &s);
	if (steps == NULL) {
		error = ACTION_ERROR_FATAL;
		goto out;
	}
	if (offset - 1 >= VECTOR_LENGTH(steps)) {
		warnx("offset %u too large", offset);
		error = ACTION_ERROR_FATAL;
		goto out;
	}
	for (i = offset - 1; i < VECTOR_LENGTH(steps); i++) {
		printf("%zu %s%s\n",
		    i + 1,
		    steps[i].name,
		    steps[i].flags.parallel ? " parallel" : "");
	}

out:
	config_free(config);
	return error;
}
