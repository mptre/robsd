#include "config.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "buffer.h"
#include "regress-log.h"

static __dead void	usage(void);

int
main(int argc, char *argv[])
{
	struct buffer *bf;
	unsigned int flags = 0;
	int doprint = 1;
	int ch, n;

	if (pledge("stdio rpath unveil", NULL) == -1)
		err(1, "pledge");

	while ((ch = getopt(argc, argv, "EFSn")) != -1) {
		switch (ch) {
		case 'E':
			flags |= REGRESS_LOG_ERROR;
			break;
		case 'F':
			flags |= REGRESS_LOG_FAILED;
			break;
		case 'S':
			flags |= REGRESS_LOG_SKIPPED;
			break;
		case 'n':
			doprint = 0;
			break;
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;
	if (argc != 1 || flags == 0)
		usage();

	if (unveil(*argv, "r") == -1)
		err(1, "unveil: %s", *argv);
	if (pledge("stdio rpath", NULL) == -1)
		err(1, "pledge");

	bf = buffer_alloc(1 << 20);
	regress_log_init();
	n = regress_log_parse(*argv, bf, flags);
	regress_log_shutdown();
	if (n > 0 && doprint)
		printf("%.*s", (int)bf->bf_len, bf->bf_ptr);
	buffer_free(bf);
	if (n == -1)
		return 2;
	if (n == 0)
		return 1;
	return 0;
}

static __dead void
usage(void)
{
	fprintf(stderr, "usage: robsd-regress-log [-EFSn] path\n");
	exit(1);
}
