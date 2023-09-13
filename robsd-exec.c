#include "config.h"

#include "step-exec.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static void	usage(void) __attribute__((__noreturn__));

int
main(int argc, char *argv[])
{
	int error;

	if (argc < 2)
		usage();

	if (pledge("stdio proc exec", NULL) == -1)
		err(1, "pledge");

	error = step_exec(&argv[1]);

	return error;
}

static void
usage(void)
{
	fprintf(stderr, "usage: robsd-exec utility [argument ...]\n");
	exit(1);
}
