#include "config.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "regress-html.h"
#include "regress-log.h"

static __dead void	usage(void);

int
main(int argc, char *argv[])
{
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

	regress_log_init();
	rh = regress_html_alloc(output);

	for (; argc > 0; argc--, argv++) {
		const char *colon, *path;
		char *arch;

		colon = strchr(argv[0], ':');
		if (colon == NULL) {
			warnx("%s: invalid argument", argv[0]);
			error = 1;
			goto out;
		}
		arch = strndup(argv[0], colon - argv[0]);
		if (arch == NULL)
			err(1, NULL);
		path = &colon[1];
		error = regress_html_parse(rh, arch, path);
		free(arch);
		if (error)
			goto out;
	}
	error = regress_html_render(rh);

out:
	regress_html_free(rh);
	regress_log_shutdown();
	return error;
}

static __dead void
usage(void)
{
	fprintf(stderr, "usage: robsd-regress-html -o output arch:path ...\n");
	exit(1);
}