#include "config.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "libks/arena.h"

#include "regress-html.h"

static void	usage(void) __attribute__((__noreturn__));

int
main(int argc, char *argv[])
{
	ARENA arena[256 * 1024];
	struct regress_html *rh;
	const char *output = NULL;
	int error = 0;
	int ch;

	while ((ch = getopt(argc, argv, "o:")) != -1) {
		switch (ch) {
		case 'o':
			output = optarg;
			break;
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;
	if (argc == 0 || output == NULL)
		usage();

	if (pledge("stdio rpath wpath cpath", NULL) == -1)
		err(1, "pledge");

	if (arena_init(arena, ARENA_FATAL))
		err(1, "arena_init");

	ARENA_SCOPE s = arena_scope(arena);
	rh = regress_html_alloc(output, &s);

	for (; argc > 0; argc--, argv++) {
		const char *arch, *colon, *path;

		colon = strchr(argv[0], ':');
		if (colon == NULL) {
			warnx("%s: invalid argument", argv[0]);
			error = 1;
			goto out;
		}
		arch = arena_strndup(&s, argv[0], (size_t)(colon - argv[0]));
		path = &colon[1];
		error = regress_html_parse(rh, arch, path);
		if (error)
			goto out;
	}
	error = regress_html_render(rh);

out:
	regress_html_free(rh);
	arena_free(arena);
	return error;
}

static void
usage(void)
{
	fprintf(stderr, "usage: robsd-regress-html -o output arch:path ...\n");
	exit(1);
}
