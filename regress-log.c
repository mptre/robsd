#include "regress-log.h"

#include "config.h"

#include <err.h>
#include <regex.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "buffer.h"

struct reader {
	const char	*path;
	FILE		*fh;
	char		*line;
	size_t		 linesiz;
};

static int	reader_open(struct reader *, const char *);
static ssize_t	reader_getline(struct reader *, const char **);
static void	reader_close(struct reader *);

static int	iserror(const char *);
static int	ismarker(const char *);
static int	isskipped(const char *);
static int	isfailed(const char *);
static int	isxfailed(const char *);
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
 *     REGRESS_LOG_XFAILED    Extract expected failed test cases.
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
	struct reader rd;
	struct buffer *bf;
	size_t errorlen = 0;
	int error = 0;
	int nfound = 0;
	int xtrace = 1;

	if (reader_open(&rd, path))
		return 1;

	buffer_reset(out);
	bf = buffer_alloc(1 << 20);
	if (bf == NULL)
		err(1, NULL);
	for (;;) {
		const char *line;
		ssize_t n;

		n = reader_getline(&rd, &line);
		if (n == -1) {
			error = 1;
			break;
		}
		if (n == 0)
			break;
		if (xtrace && isxtrace(line))
			continue;
		xtrace = 0;

		if (ismarker(line))
			buffer_reset(bf);
		buffer_puts(bf, line, (size_t)n);

		if ((flags & REGRESS_LOG_ERROR) && iserror(line))
			errorlen = buffer_get_len(bf);

		if (((flags & REGRESS_LOG_SKIPPED) && isskipped(line)) ||
		    ((flags & REGRESS_LOG_FAILED) && isfailed(line)) ||
		    ((flags & REGRESS_LOG_XFAILED) && isxfailed(line))) {
			if (nfound > 0)
				buffer_putc(out, '\n');
			buffer_putc(bf, '\0');
			buffer_printf(out, "%s", buffer_get_ptr(bf));
			buffer_reset(bf);
			nfound++;
			errorlen = 0;
		}
	}
	if ((flags & REGRESS_LOG_ERROR) && nfound == 0 && !error &&
	    errorlen > 0) {
		buffer_printf(out, "%.*s", (int)errorlen, buffer_get_ptr(bf));
		nfound++;
	}
	buffer_free(bf);
	reader_close(&rd);

	if (error)
		return -1;
	return nfound;
}

/*
 * Remove shell trace(s) from the given file.
 */
int
regress_log_trim(const char *path, struct buffer *out)
{
	struct reader rd;
	struct buffer *bf;
	size_t xbeg = 1;
	size_t xend = 0;
	int error = 0;

	if (reader_open(&rd, path))
		return 1;

	buffer_reset(out);
	bf = buffer_alloc(1 << 20);
	if (bf == NULL)
		err(1, NULL);
	for (;;) {
		const char *line;
		ssize_t n;

		n = reader_getline(&rd, &line);
		if (n == -1) {
			error = 1;
			goto out;
		}
		if (n == 0)
			break;
		if (xbeg != 0 && isxtrace(line))
			continue;
		xbeg = 0;

		if (isxtrace(line)) {
			if (xend == 0)
				xend = buffer_get_len(bf);
		} else {
			xend = 0;
		}

		buffer_puts(bf, line, (size_t)n);
	}

	buffer_printf(out, "%.*s", (int)(xend ? xend : buffer_get_len(bf)),
	    buffer_get_ptr(bf));

out:
	buffer_free(bf);
	reader_close(&rd);
	return error ? 0 : 1;
}

static int
reader_open(struct reader *rd, const char *path)
{
	memset(rd, 0, sizeof(*rd));
	rd->fh = fopen(path, "re");
	if (rd->fh == NULL) {
		warn("open: %s", path);
		return 1;
	}
	return 0;
}

static ssize_t
reader_getline(struct reader *rd, const char **out)
{
	ssize_t n;

	n = getline(&rd->line, &rd->linesiz, rd->fh);
	if (n == -1) {
		if (feof(rd->fh))
			return 0;
		warn("getline: %s", rd->path);
		return -1;
	}
	*out = rd->line;
	return n;
}

static void
reader_close(struct reader *rd)
{
	free(rd->line);
	fclose(rd->fh);
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
	return strstr(str, "FAILED") != NULL ||
	    strstr(str, "UNEXPECTED_PASS") != NULL;
}

static int
isxfailed(const char *str)
{
	return strstr(str, "EXPECTED_FAIL") != NULL;
}

static int
isxtrace(const char *str)
{
	return str[0] == '+';
}
