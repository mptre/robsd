#include "config.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "libks/arena.h"
#include "libks/buffer.h"

#include "conf.h"
#include "report.h"

static void	usage(void) __attribute__((__noreturn__));

int
main(int argc, char *argv[])
{
	struct arena *eternal, *scratch;
	struct buffer *bf = NULL;
	struct config *config = NULL;
	const char *config_path = NULL;
	const char *mode = NULL;
	int error = 1;
	int ch;

	if (pledge("stdio rpath flock", NULL) == -1)
		err(1, "pledge");

	while ((ch = getopt(argc, argv, "C:m:")) != -1) {
		switch (ch) {
		case 'C':
			config_path = optarg;
			break;
		case 'm':
			mode = optarg;
			break;
		}
	}
	argc -= optind;
	argv += optind;
	if (argc != 1 || mode == NULL)
		usage();

	eternal = arena_alloc(ARENA_FATAL);
	arena_scope(eternal, eternal_scope);
	scratch = arena_alloc(ARENA_FATAL);

	config = config_alloc(mode, config_path, &eternal_scope, scratch);
	if (config == NULL || config_parse(config))
		goto out;

	bf = buffer_alloc(1 << 14);
	if (bf == NULL)
		goto out;

	error = report_generate(config, argv[0], bf);
	if (error)
		goto out;
	buffer_putc(bf, '\0');
	printf("%s", buffer_get_ptr(bf));

out:
	buffer_free(bf);
	config_free(config);
	arena_free(scratch);
	arena_free(eternal);
	return error;
}

static void
usage(void)
{
	fprintf(stderr, "usage: robsd-report -m mode path\n");
	exit(1);
}
