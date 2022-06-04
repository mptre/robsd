#include <sys/queue.h>

#include <err.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "extern.h"

void
log_warn(const char *path, int lno, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	logv(warn, path, lno, fmt, ap);
	va_end(ap);
}

void
log_warnx(const char *path, int lno, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	logv(warnx, path, lno, fmt, ap);
	va_end(ap);
}

void
logv(void (*pr)(const char *, ...), const char *path, int lno, const char *fmt,
    va_list ap)
{
	char msg[512], line[16];

	if (lno == 0)
		line[0] = '\0';
	else
		(void)snprintf(line, sizeof(line), "%d:", lno);

	(void)vsnprintf(msg, sizeof(msg), fmt, ap);
	(pr)("%s:%s %s", path, line, msg);
}

struct string_list *
strings_alloc(void)
{
	struct string_list *strings;

	strings = malloc(sizeof(*strings));
	if (strings == NULL)
		err(1, NULL);
	TAILQ_INIT(strings);
	return strings;
}

void
strings_free(struct string_list *strings)
{
	struct string *st;

	if (strings == NULL)
		return;

	while ((st = TAILQ_FIRST(strings)) != NULL) {
		TAILQ_REMOVE(strings, st, st_entry);
		free(st->st_val);
		free(st);
	}
	free(strings);
}

void
strings_append(struct string_list *strings, const char *val)
{
	struct string *st;

	st = malloc(sizeof(*st));
	if (st == NULL)
		err(1, NULL);
	st->st_val = strdup(val);
	if (st->st_val == NULL)
		err(1, NULL);
	TAILQ_INSERT_TAIL(strings, st, st_entry);
}

unsigned int
strings_len(const struct string_list *strings)
{
	const struct string *st;
	unsigned int len = 0;

	TAILQ_FOREACH(st, strings, st_entry)
		len++;
	return len;
}
