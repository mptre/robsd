#include "config.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "buffer.h"
#include "regress-log.h"

static void	usage(void) __attribute__((__noreturn__));

int
main(int argc, char *argv[])
{
	struct buffer *bf;
	unsigned int flags = 0;
	int doprint = 1;
	int ch, n;

	if (pledge("stdio rpath unveil", NULL) == -1)
		err(1, "pledge");

	while ((ch = getopt(argc, argv, "FSXn")) != -1) {
		switch (ch) {
		case 'F':
			flags |= REGRESS_LOG_FAILED;
			break;
		case 'S':
			flags |= REGRESS_LOG_SKIPPED;
			break;
		case 'X':
			flags |= REGRESS_LOG_XFAILED;
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
	if (bf == NULL)
		err(1, NULL);
	regress_log_init();
	n = regress_log_parse(*argv, bf, flags);
	regress_log_shutdown();
	if (n > 0 && doprint) {
		buffer_putc(bf, '\0');
		printf("%s", buffer_get_ptr(bf));
	}
	buffer_free(bf);
	if (n == -1)
		return 2;
	if (n == 0)
		return 1;
	return 0;
}

static void
usage(void)
{
	fprintf(stderr, "usage: robsd-regress-log [-FSXn] path\n");
	exit(1);
}
