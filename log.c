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
	log_vwarnx(path, lno, fmt, ap);
	va_end(ap);
}

void
log_vwarnx(const char *path, int lno, const char *fmt, va_list ap)
{
	char msg[512], line[16];

	if (!log_enable)
		return;

	if (lno == 0)
		line[0] = '\0';
	else
		(void)snprintf(line, sizeof(line), "%d:", lno);

	(void)vsnprintf(msg, sizeof(msg), fmt, ap);
	warnx("%s%s%s%s%s",
	    path ? path : "",
	    path ? ":" : "",
	    line,
	    path ? " " : "",
	    msg);
}
