#include "log.h"

#include "config.h"

#include <err.h>
#include <stdarg.h>
#include <stdio.h>

static int log_enable = 1;

void
log_disable(void)
{
	log_enable = 0;
}

void
log_warnx(const char *path, int lno, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	logv(LOG_WARNX, path, lno, fmt, ap);
	va_end(ap);
}

void
logv(enum log_func fun, const char *path, int lno, const char *fmt,
    va_list ap)
{
	void (*functions[])(const char *, ...) = {
		[LOG_WARN]	= warn,
		[LOG_WARNX]	= warnx,
	};
	char msg[512], line[16];

	if (!log_enable)
		return;

	if (lno == 0)
		line[0] = '\0';
	else
		(void)snprintf(line, sizeof(line), "%d:", lno);

	(void)vsnprintf(msg, sizeof(msg), fmt, ap);
	(functions[fun])("%s%s%s%s%s",
	    path ? path : "",
	    path ? ":" : "",
	    line,
	    path ? " " : "",
	    msg);
}
