#include "regress-log.h"

#include <err.h>
#include <regex.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "buffer.h"

static int	iserror(const char *);
static int	ismarker(const char *);
static int	isskipped(const char *);
static int	isfailed(const char *);
static int	isxtrace(const char *);

static regex_t	reg_regress, reg_subdir;

void
regress_log_init(void)
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

void
regress_log_shutdown(void)
{
	regfree(&reg_regress);
	regfree(&reg_subdir);
}

/*
 * Parse the given log located at path and extract regress test cases with a
 * specific outcome. The flags may be any combination of the following:
 *
 *     REGRESS_LOG_FAILED     Extract failed test cases.
 *     REGRESS_LOG_SKIPPED    Extract skipped test cases.
 *     REGRESS_LOG_ERROR      If no test cases are found, extract make errors.
 *
 * Returns one of the following:
 *
 *     >0    At least one or more test cases extracted.
 *     0     No test cases extracted.
 *     <0    Fatal error occurred.
 */
int
regress_log_parse(const char *path, struct buffer *out, unsigned int flags)
{
	struct buffer *bf;
	char *line = NULL;
	size_t errorlen = 0;
	size_t linesiz = 0;
	FILE *fh;
	int error = 0;
	int nfound = 0;
	int xtrace = 1;

	fh = fopen(path, "re");
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
		if (xtrace && isxtrace(line))
			continue;
		xtrace = 0;

		if (ismarker(line))
			buffer_reset(bf);
		buffer_puts(bf, line, n);

		if ((flags & REGRESS_LOG_ERROR) && iserror(line))
			errorlen = bf->bf_len;

		if (((flags & REGRESS_LOG_SKIPPED) && isskipped(line)) ||
		    ((flags & REGRESS_LOG_FAILED) && isfailed(line))) {
			if (nfound > 0)
				buffer_putc(out, '\n');
			buffer_printf(out, "%.*s", (int)bf->bf_len, bf->bf_ptr);
			buffer_reset(bf);
			nfound++;
			errorlen = 0;
		}
	}
	if ((flags & REGRESS_LOG_ERROR) && nfound == 0 && !error && errorlen > 0) {
		buffer_printf(out, "%.*s", (int)errorlen, bf->bf_ptr);
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

static int
isxtrace(const char *str)
{
	return str[0] == '+';
}
