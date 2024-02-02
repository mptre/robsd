#include "regress-log.h"

#include "config.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "libks/buffer.h"
#include "libks/consistency.h"

static int	regress_log_parse_impl(const char *, struct buffer *,
    struct buffer *, unsigned int);

static int	ismarker(const char *);
static int	ismarker_regress(const char *);
static int	ismarker_subdir(const char *);
static int	isskipped(const char *);
static int	isfailed(const char *);
static int	isxfailed(const char *);
static int	isxpassed(const char *);
static int	isxtrace(const char *);

int
regress_log_parse(const char *path, struct buffer *out, unsigned int flags)
{
	struct buffer *scratch;
	int rv;

	scratch = buffer_alloc(1 << 20);
	if (scratch == NULL)
		err(1, NULL);
	rv = regress_log_parse_impl(path, scratch, out, flags);
	buffer_free(scratch);
	return rv;
}

/*
 * Parse the given log located at path and extract regress test targets with a
 * specific outcome. Returns one of the following:
 *
 *     >0    At least one or more test targets extracted.
 *     0     No test targets extracted.
 *     <0    Fatal error occurred.
 */
static int
regress_log_parse_impl(const char *path, struct buffer *scratch,
    struct buffer *out, unsigned int flags)
{
	struct buffer *bf;
	struct buffer_getline *it = NULL;
	int error = 0;
	int nfound = 0;
	int xtrace = 1;

	ASSERT_CONSISTENCY(flags & REGRESS_LOG_PEEK, out == NULL);

	bf = buffer_read(path);
	if (bf == NULL)
		return -1;

	for (;;) {
		const char *line;

		line = buffer_getline(bf, &it);
		if (line == NULL)
			break;
		if (xtrace && isxtrace(line))
			continue;
		xtrace = 0;

		if (ismarker(line))
			buffer_reset(scratch);
		buffer_puts(scratch, line, strlen(line));
		buffer_putc(scratch, '\n');

		if (((flags & REGRESS_LOG_SKIPPED) && isskipped(line)) ||
		    ((flags & REGRESS_LOG_FAILED) && isfailed(line)) ||
		    ((flags & REGRESS_LOG_XFAILED) && isxfailed(line)) ||
		    ((flags & REGRESS_LOG_XPASSED) && isxpassed(line))) {
			int first = nfound == 0 &&
			    (flags & REGRESS_LOG_NEWLINE) == 0;

			nfound++;
			if (flags & REGRESS_LOG_PEEK)
				break;

			if (!first)
				buffer_putc(out, '\n');
			buffer_putc(scratch, '\0');
			buffer_printf(out, "%s", buffer_get_ptr(scratch));
			buffer_reset(scratch);
		}
	}

	buffer_getline_free(it);
	buffer_free(bf);

	if (error)
		return -1;
	return nfound;
}

int
regress_log_peek(const char *path, unsigned int flags)
{
	struct buffer *scratch;
	int rv;

	scratch = buffer_alloc(1 << 10);
	if (scratch == NULL)
		err(1, NULL);
	rv = regress_log_parse_impl(path, scratch, NULL,
	    flags | REGRESS_LOG_PEEK);
	buffer_free(scratch);
	return rv;
}

/*
 * Remove shell trace(s) from the given file.
 */
int
regress_log_trim(const char *path, struct buffer *out)
{
	struct buffer *bf, *rd;
	struct buffer_getline *it = NULL;
	size_t xbeg = 1;
	size_t xend = 0;
	int error = 0;

	rd = buffer_read(path);
	if (rd == NULL)
		return -1;

	buffer_reset(out);
	bf = buffer_alloc(1 << 20);
	if (bf == NULL)
		err(1, NULL);
	for (;;) {
		const char *line;

		line = buffer_getline(rd, &it);
		if (line == NULL)
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

		buffer_puts(bf, line, strlen(line));
		buffer_putc(bf, '\n');
	}

	buffer_printf(out, "%.*s", (int)(xend ? xend : buffer_get_len(bf)),
	    buffer_get_ptr(bf));

	buffer_free(bf);
	buffer_getline_free(it);
	buffer_free(rd);
	return error ? -1 : 1;
}

static int
ismarker(const char *str)
{
	return ismarker_regress(str) || ismarker_subdir(str);
}

/*
 * Returns non-zero if str matches /^==== .* ====$/.
 */
static int
ismarker_regress(const char *str)
{
	const char needle[] = "====";

	if (strncmp(str, needle, sizeof(needle) - 1) != 0)
		return 0;
	str += sizeof(needle) - 1;

	if (str[0] != ' ')
		return 0;
	str += 1;

	for (; str[0] != '\0'; str++) {
		if (str[-1] == ' ' && str[0] == '=')
			break;
	}

	if (strncmp(str, needle, sizeof(needle) - 1) != 0)
		return 0;
	str += sizeof(needle) - 1;

	return str[0] == '\0';
}

static int
ismarker_subdir(const char *str)
{
	const char needle[] = "===>";

	return strncmp(str, needle, sizeof(needle) - 1) == 0;
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
isxfailed(const char *str)
{
	return strstr(str, "EXPECTED_FAIL") != NULL;
}

static int
isxpassed(const char *str)
{
	return strstr(str, "UNEXPECTED_PASS") != NULL;
}

static int
isxtrace(const char *str)
{
	return str[0] == '+';
}
