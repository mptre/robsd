#include "config.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "buffer.h"
#include "interpolate.h"
#include "step.h"
#include "vector.h"

enum step_mode {
	MODE_READ = 1,
	MODE_WRITE,
};

struct step_context {
	const char		*sc_path;
	VECTOR(struct step)	 sc_steps;
};

static __dead void	usage(void);

static int	steps_read(struct step_context *, int, char **);
static int	steps_write(struct step_context *, int, char **);

int
main(int argc, char *argv[])
{
	struct step_context sc;
	int mode = 0;
	int error = 0;
	int ch;

	memset(&sc, 0, sizeof(sc));

	opterr = 0;
	while ((ch = getopt(argc, argv, "RWf:")) != -1) {
		int dobreak = 0;

		switch (ch) {
		case 'R':
			mode = MODE_READ;
			break;
		case 'W':
			mode = MODE_WRITE;
			break;
		case 'f':
			sc.sc_path = optarg;
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
	if (mode == 0 || sc.sc_path == NULL)
		usage();

	sc.sc_steps = steps_parse(sc.sc_path);
	if (sc.sc_steps == NULL) {
		error = 1;
		goto out;
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
	}

out:
	steps_free(sc.sc_steps);
	return error;
}

static __dead void
usage(void)
{
	fprintf(stderr,
	    "usage: robsd-step -R -f path [-l line] [-n name]\n"
	    "       robsd-step -W -f path -i id -- key=val ...\n");
	exit(1);
}

static int
steps_read(struct step_context *sc, int argc, char **argv)
{
	struct step *st;
	const char *name = NULL;
	const char *errstr;
	char *str;
	size_t nsteps;
	int error = 0;
	int gotlno = 0;
	int lno = 0;
	int ch;

	while ((ch = getopt(argc, argv, "l:n:")) != -1) {
		switch (ch) {
		case 'l':
			lno = strtonum(optarg, -INT_MAX, INT_MAX, &errstr);
			if (errstr != NULL) {
				warnx("line %s %s", optarg, errstr);
				return 1;
			}
			gotlno = 1;
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
	if (name != NULL && gotlno) {
		warnx("-l and -n are mutually exclusive");
		return 1;
	}

	nsteps = VECTOR_LENGTH(sc->sc_steps);
	if (name != NULL) {
		st = steps_find_by_name(sc->sc_steps, name);
		if (st == NULL) {
			warnx("step with name '%s' not found", name);
			return 1;
		}
	} else if (lno > 0 && (size_t)lno - 1 < nsteps) {
		st = &sc->sc_steps[lno - 1];
	} else if (lno < 0 && (size_t)-lno <= nsteps) {
		st = &sc->sc_steps[nsteps + lno];
	} else {
		warnx("step at line %d not found", lno);
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
	struct step *st;
	const char *errstr;
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
			id = strtonum(optarg, -INT_MAX, INT_MAX, &errstr);
			if (errstr != NULL) {
				warnx("id %s %s", optarg, errstr);
				return 1;
			}
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

	if (doheader) {
		steps_header(bf);
		printf("%.*s", (int)bf->bf_len, bf->bf_ptr);
		goto out;
	}

	st = steps_find_by_id(sc->sc_steps, id);
	if (st == NULL) {
		st = VECTOR_CALLOC(sc->sc_steps);
		if (st == NULL)
			err(1, NULL);
		if (step_init(st, id)) {
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

	steps_sort(sc->sc_steps);
	steps_header(bf);
	for (i = 0; i < VECTOR_LENGTH(sc->sc_steps); i++) {
		if (step_serialize(&sc->sc_steps[i], bf)) {
			error = 1;
			goto out;
		}
	}

	fh = fopen(sc->sc_path, "w");
	if (fh == NULL) {
		warn("fopen: %s", sc->sc_path);
		error = 1;
		goto out;
	}
	n = fwrite(bf->bf_ptr, bf->bf_len, 1, fh);
	if (n < 1) {
		warn("fwrite: %s", sc->sc_path);
		error = 1;
		goto out;
	}

out:
	if (fh != NULL)
		fclose(fh);
	buffer_free(bf);
	return error;
}
