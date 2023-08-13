#include "config.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "libks/buffer.h"

#include "regress-log.h"

static void	usage(void) __attribute__((__noreturn__));

int
main(int argc, char *argv[])
{
	struct buffer *bf;
	unsigned int flags = 0;
	int doprint = 1;
	int error = 0;
	int n = 0;
	int ch, i;

	if (pledge("stdio rpath unveil", NULL) == -1)
		err(1, "pledge");

	while ((ch = getopt(argc, argv, "EFPSXn")) != -1) {
		switch (ch) {
		case 'E':
			flags |= REGRESS_LOG_ERROR;
			break;
		case 'F':
			flags |= REGRESS_LOG_FAILED;
			break;
		case 'P':
			flags |= REGRESS_LOG_XPASSED;
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
	if (argc == 0 || flags == 0)
		usage();

	for (i = 0; i < argc; i++) {
		if (unveil(argv[i], "r") == -1)
			err(1, "unveil: %s", argv[i]);
	}
	if (pledge("stdio rpath", NULL) == -1)
		err(1, "pledge");

	bf = buffer_alloc(1 << 20);
	if (bf == NULL)
		err(1, NULL);
	for (i = 0; i < argc; i++) {
		if (n > 0)
			buffer_putc(bf, '\n');
		switch (regress_log_parse(argv[i], bf, flags)) {
		case -1:
			error = 1;
			break;
		case 0:
			if (n > 0)
				buffer_pop(bf, 1);
			break;
		default:
			n++;
		}
	}
	if (!error && n > 0 && doprint) {
		buffer_putc(bf, '\0');
		printf("%s", buffer_get_ptr(bf));
	}
	buffer_free(bf);
	if (error)
		return 2;
	if (n == 0)
		return 1;
	return 0;
}

static void
usage(void)
{
	fprintf(stderr, "usage: robsd-regress-log [-EFPSXn] path ...\n");
	exit(1);
}
