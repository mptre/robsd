#include "config.h"

#include <ctype.h>
#include <err.h>
#include <fcntl.h>
#include <regex.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "buffer.h"
#include "extern.h"

static __dead void	usage(void);

#define FLAG_FAILED	0x00000001u
#define FLAG_SKIPPED	0x00000002u
#define FLAG_ERROR	0x00000004u
#define FLAG_PRINT	0x00000008u

static int	parselog(const char *, unsigned int);
static int	iserror(const char *);
static int	ismarker(const char *);
static int	isskipped(const char *);
static int	isfailed(const char *);

static void	reg_init(void);
static void	reg_shutdown(void);

static regex_t	reg_regress, reg_subdir;

int
main(int argc, char *argv[])
{
	unsigned int flags = FLAG_PRINT;
	int ch, n;

	if (pledge("stdio rpath unveil", NULL) == -1)
		err(1, "pledge");

	while ((ch = getopt(argc, argv, "EFSn")) != -1) {
		switch (ch) {
		case 'E':
			flags |= FLAG_ERROR;
			break;
		case 'F':
			flags |= FLAG_FAILED;
			break;
		case 'S':
			flags |= FLAG_SKIPPED;
			break;
		case 'n':
			flags &= ~FLAG_PRINT;
			break;
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;
	if (argc != 1 ||
	    (flags & (FLAG_FAILED | FLAG_SKIPPED | FLAG_ERROR)) == 0)
		usage();

	if (unveil(*argv, "r") == -1)
		err(1, "unveil: %s", *argv);
	if (pledge("stdio rpath", NULL) == -1)
		err(1, "pledge");

	reg_init();
	n = parselog(*argv, flags);
	reg_shutdown();
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

/*
 * Parse the given log located at path and extract regress test cases with a
 * specific outcome. The flags may be any combination of the following:
 *
 *     FLAG_FAILED     Extract failed test cases.
 *     FLAG_SKIPPED    Extract skipped test cases.
 *     FLAG_ERROR      If no test cases are found, extract make errors.
 *     FLAG_PRINT      Output extracted test cases.
 *
 * Returns one of the following:
 *
 *     >0    At least one or more test cases extracted.
 *     0     No test cases extracted.
 *     <0    Fatal error occurred.
 */
static int
parselog(const char *path, unsigned int flags)
{
	struct buffer *bf;
	char *line = NULL;
	size_t errorlen = 0;
	size_t linesiz = 0;
	FILE *fh;
	int error = 0;
	int nfound = 0;

	fh = fopen(path, "r");
	if (fh == NULL) {
		warn("open: %s", path);
		return -1;
	}

	bf = buffer_alloc(1 << 20);

	for (;;) {
		ssize_t n;

		n = getline(&line, &linesiz, fh);
		if (n == -1) {
			if (feof(fh))
				break;
			warn("getline: %s", path);
			error = 1;
			break;
		}

		if (ismarker(line))
			buffer_reset(bf);
		buffer_append(bf, line, n);

		if ((flags & FLAG_ERROR) && iserror(line))
			errorlen = bf->bf_len;

		if (((flags & FLAG_SKIPPED) && isskipped(line)) ||
		    ((flags & FLAG_FAILED) && isfailed(line))) {
			if (flags & FLAG_PRINT) {
				if (nfound > 0)
					printf("\n");
				printf("%.*s", (int)bf->bf_len, bf->bf_ptr);
			}
			buffer_reset(bf);
			nfound++;
			errorlen = 0;
		}
	}
	if ((flags & FLAG_ERROR) && nfound == 0 && !error && errorlen > 0) {
		printf("%.*s", (int)errorlen, bf->bf_ptr);
		nfound++;
	}
	free(line);
	buffer_free(bf);
	fclose(fh);

	if (error)
		return -1;
	return nfound;
}

static int
iserror(const char *str)
{
	static const char needle[] = "*** Error ";

	return strncmp(str, needle, sizeof(needle) - 1) == 0;
}

static int
ismarker(const char *str)
{
	if (regexec(&reg_regress, str, 0, NULL, 0) == 0)
		return 1;
	if (regexec(&reg_subdir, str, 0, NULL, 0) == 0)
		return 1;
	return 0;
}

static int
isskipped(const char *str)
{
	return strstr(str, "SKIPPED") != NULL ||
	    strstr(str, "DISABLED") != NULL;
}

static int
isfailed(const char *str)
{
	return strstr(str, "FAILED") != NULL;
}

static void
reg_init(void)
{
	char errbuf[512];
	int flags = REG_NOSUB | REG_NEWLINE;
	int error;

	error = regcomp(&reg_subdir, "^===>", flags);
	if (error) {
		(void)regerror(error, &reg_subdir, errbuf, sizeof(errbuf));
		errx(1, "regcomp: %s", errbuf);
	}

	error = regcomp(&reg_regress, "^==== .* ====$", flags);
	if (error) {
		(void)regerror(error, &reg_regress, errbuf, sizeof(errbuf));
		errx(1, "regcomp: %s", errbuf);
	}
}

static void
reg_shutdown(void)
{
	regfree(&reg_regress);
	regfree(&reg_subdir);
}
