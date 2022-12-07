#include "interpolate.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "alloc.h"
#include "buffer.h"
#include "util.h"

struct interpolate_context {
	const struct interpolate_arg	*ic_arg;
	const char			*ic_path;
	int				 ic_lno;
};

static int	interpolate(const struct interpolate_context *,
    struct buffer *, const char *);

char *
interpolate_file(const char *path, const struct interpolate_arg *arg)
{
	struct interpolate_context ic = {
		.ic_arg		= arg,
		.ic_path	= path,
		.ic_lno		= arg->lno,
	};
	FILE *fh;
	struct buffer *bf;
	char *buf = NULL;
	char *line = NULL;
	size_t linesiz = 0;
	int error = 0;

	fh = fopen(path, "re");
	if (fh == NULL) {
		warn("open: %s", path);
		return NULL;
	}

	bf = buffer_alloc(1024);
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
		ic.ic_lno++;
		if (interpolate(&ic, bf, line)) {
			error = 1;
			break;
		}
	}
	if (error == 0) {
		buffer_putc(bf, '\0');
		buf = buffer_release(bf);
	}
	buffer_free(bf);
	free(line);
	fclose(fh);
	return buf;
}

char *
interpolate_str(const char *str, const struct interpolate_arg *arg)
{
	struct interpolate_context ic = {
		.ic_arg	= arg,
		.ic_lno	= arg->lno,
	};
	struct buffer *bf;
	char *buf = NULL;

	bf = buffer_alloc(1024);
	if (interpolate(&ic, bf, str) == 0) {
		buffer_putc(bf, '\0');
		buf = buffer_release(bf);
	}
	buffer_free(bf);
	return buf;
}

int
interpolate_buffer(const char *str, struct buffer *bf,
    const struct interpolate_arg *arg)
{
	struct interpolate_context ic = {
		.ic_arg	= arg,
		.ic_lno	= arg->lno,
	};
	int error;

	error = interpolate(&ic, bf, str);
	return error;
}

static int
interpolate(const struct interpolate_context *ic, struct buffer *bf,
    const char *str)
{
	for (;;) {
		const char *p, *ve, *vs;
		char *lookup, *name, *rep;
		size_t len;

		p = strchr(str, '$');
		if (p == NULL)
			break;
		vs = &p[1];
		if (*vs != '{') {
			log_warnx(ic->ic_path, ic->ic_lno,
			    "invalid substitution, expected '{'");
			return 1;
		}
		vs += 1;
		ve = strchr(vs, '}');
		if (ve == NULL) {
			log_warnx(ic->ic_path, ic->ic_lno,
			    "invalid substitution, expected '}'");
			return 1;
		}
		len = ve - vs;
		if (len == 0) {
			log_warnx(ic->ic_path, ic->ic_lno,
			    "invalid substitution, empty variable name");
			return 1;
		}

		name = estrndup(vs, len);
		lookup = ic->ic_arg->lookup(name, ic->ic_arg->arg);
		free(name);
		if (lookup == NULL) {
			log_warnx(ic->ic_path, ic->ic_lno,
			    "invalid substitution, unknown variable '%.*s'",
			    (int)len, vs);
			return 1;
		}
		rep = interpolate_str(lookup, ic->ic_arg);
		buffer_puts(bf, str, p - str);
		buffer_puts(bf, rep, strlen(rep));
		free(rep);
		free(lookup);
		str = &ve[1];
	}
	/* Output any remaining tail. */
	buffer_puts(bf, str, strlen(str));

	return 0;
}
