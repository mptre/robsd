#include "config.h"

#include <err.h>
#include <limits.h>	/* PATH_MAX */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "libks/buffer.h"
#include "libks/compiler.h"
#include "libks/vector.h"

#include "conf.h"
#include "interpolate.h"
#include "step.h"

enum step_mode {
	MODE_READ = 1,
	MODE_WRITE,
	MODE_LIST,
};

struct step_context {
	const char		*path;
	struct step_file	*step_file;
};

static void	usage(void) __attribute__((__noreturn__));

static int	steps_read(struct step_context *, int, char **);
static int	steps_write(struct step_context *, int, char **);
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
	struct step_context sc = {0};
	enum step_mode mode = 0;
	int error = 0;
	int ch;

	if (pledge("stdio rpath wpath cpath flock unveil", NULL) == -1)
		err(1, "pledge");

	opterr = 0;
	while ((ch = getopt(argc, argv, "LRWf:")) != -1) {
		int dobreak = 0;

		switch (ch) {
		case 'L':
			mode = MODE_LIST;
			break;
		case 'R':
			mode = MODE_READ;
			break;
		case 'W':
			mode = MODE_WRITE;
			break;
		case 'f':
			sc.path = optarg;
			break;
		default:
			dobreak = 1;
		}
		if (dobreak)
			break;
	}
	if (optind >= 2) {
		argc -= optind - 2;
		argv += optind - 2;
	}
	if (mode == 0)
		usage();

	switch (mode) {
	case MODE_READ:
		if (sc.path == NULL)
			usage();
		if (unveil("/dev/stdin", "r") == -1)
			err(1, "unveil: /dev/stdin");
		if (unveil(sc.path, "r") == -1)
			err(1, "unveil: %s", sc.path);
		if (pledge("stdio rpath flock", NULL) == -1)
			err(1, "pledge");
		break;
	case MODE_WRITE:
		if (sc.path == NULL)
			usage();
		if (unveil(sc.path, "rwc") == -1)
			err(1, "unveil: %s", sc.path);
		if (pledge("stdio rpath wpath cpath flock", NULL) == -1)
			err(1, "pledge");
		break;
	case MODE_LIST:
		if (pledge("stdio rpath", NULL) == -1)
			err(1, "pledge");
		break;
	}

	switch (mode) {
	case MODE_READ:
	case MODE_WRITE:
		sc.step_file = steps_parse(sc.path);
		if (sc.step_file == NULL) {
			error = 1;
			goto out;
		}
		break;
	default:
		break;
	}

	opterr = 1;
	optind = 0;
	switch (mode) {
	case MODE_READ:
		error = steps_read(&sc, argc, argv);
		break;
	case MODE_WRITE:
		error = steps_write(&sc, argc, argv);
		break;
	case MODE_LIST:
		error = steps_list(&sc, argc, argv);
		break;
	}

out:
	steps_free(sc.step_file);
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
steps_read(struct step_context *sc, int argc, char **argv)
{
	struct step *st, *steps;
	const char *name = NULL;
	char *str;
	size_t nsteps;
	int error = 0;
	int id = 0;
	int ch;

	while ((ch = getopt(argc, argv, "i:n:")) != -1) {
		switch (ch) {
		case 'i':
			if (parse_id(optarg, &id))
				return 1;
			break;
		case 'n':
			name = optarg;
			break;
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;
	if (argc > 0)
		usage();
	if (name != NULL && id != 0) {
		warnx("-i and -n are mutually exclusive");
		return 1;
	}

	steps = steps_get(sc->step_file);
	nsteps = VECTOR_LENGTH(steps);
	if (name != NULL) {
		st = steps_find_by_name(steps, name);
		if (st == NULL) {
			warnx("step with name '%s' not found", name);
			return 1;
		}
	} else if (id > 0 && (size_t)id - 1 < nsteps) {
		st = &steps[id - 1];
	} else if (id < 0 && (size_t)-id <= nsteps) {
		st = &steps[(int)nsteps + id];
	} else {
		warnx("step with id %d not found", id);
		return 1;
	}

	str = interpolate_file("/dev/stdin",
	    &(struct interpolate_arg){
		.lookup	= step_interpolate_lookup,
		.arg	= st,
	});
	if (str != NULL)
		printf("%s", str);
	else
		error = 1;
	free(str);
	return error;
}

static int
steps_write(struct step_context *sc, int argc, char **argv)
{
	FILE *fh = NULL;
	struct buffer *bf = NULL;
	struct step *st, *steps;
	size_t i;
	int id = 0;
	int error = 0;
	int doheader = 0;
	int ch, n;

	while ((ch = getopt(argc, argv, "Hi:")) != -1) {
		switch (ch) {
		case 'H':
			doheader = 1;
			break;
		case 'i':
			if (parse_id(optarg, &id))
				return 1;
			break;
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;
	if (!doheader && (argc == 0 || id == 0))
		usage();

	bf = buffer_alloc(4096);
	if (bf == NULL)
		err(1, NULL);

	if (doheader) {
		steps_header(bf);
		buffer_putc(bf, '\0');
		printf("%s", buffer_get_ptr(bf));
		goto out;
	}

	st = steps_find_by_id(steps_get(sc->step_file), id);
	if (st == NULL) {
		st = steps_alloc(sc->step_file);
		if (step_init(st) ||
		    step_set_field_integer(st, "step", id)) {
			error = 1;
			goto out;
		}
	}
	for (; argc > 0; argc--, argv++) {
		if (step_set_keyval(st, *argv)) {
			error = 1;
			goto out;
		}
	}

	steps_sort(steps_get(sc->step_file));
	steps_header(bf);
	steps = steps_get(sc->step_file);
	for (i = 0; i < VECTOR_LENGTH(steps); i++) {
		if (step_serialize(&steps[i], bf)) {
			error = 1;
			goto out;
		}
	}

	fh = fopen(sc->path, "we");
	if (fh == NULL) {
		warn("fopen: %s", sc->path);
		error = 1;
		goto out;
	}
	n = fwrite(buffer_get_ptr(bf), buffer_get_len(bf), 1, fh);
	if (n < 1) {
		warn("fwrite: %s", sc->path);
		error = 1;
		goto out;
	}

out:
	if (fh != NULL)
		fclose(fh);
	buffer_free(bf);
	return error;
}

static int
steps_list(struct step_context *UNUSED(sc), int argc, char **argv)
{
	struct config *config;
	const char *config_path = NULL;
	const char *mode = NULL;
	const char **steps;
	size_t i, nsteps;
	int ch;

	while ((ch = getopt(argc, argv, "C:m:")) != -1) {
		switch (ch) {
		case 'C':
			config_path = optarg;
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
	if (argc != 0 || mode == NULL)
		usage();

	config = config_alloc(mode, config_path);
	if (config == NULL)
		return 1;
	if (config_parse(config))
		return 1;

	steps = config_get_steps(config);
	nsteps = VECTOR_LENGTH(steps);
	for (i = 0; i < nsteps; i++)
		printf("%s\n", steps[i]);
	VECTOR_FREE(steps);

	config_free(config);

	return 0;
}
