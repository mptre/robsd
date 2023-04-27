#include "interpolate.h"

#include "config.h"

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
	int				 ic_depth;
};

static int	interpolate(struct interpolate_context *, struct buffer *,
    const char *);

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
	if (bf == NULL)
		err(1, NULL);
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
	struct buffer *bf;
	char *buf = NULL;

	bf = buffer_alloc(1024);
	if (bf == NULL)
		err(1, NULL);
	if (interpolate_buffer(str, bf, arg) == 0)
		buf = buffer_str(bf);
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
interpolate(struct interpolate_context *ic, struct buffer *bf,
    const char *str)
{
	int error = 0;

	if (++ic->ic_depth == 4) {
		log_warnx(ic->ic_path, ic->ic_lno,
		    "invalid substitution, recursion too deep");
		return 1;
	}

	for (;;) {
		const char *p, *ve, *vs;
		char *lookup, *name;
		size_t len;

		p = strchr(str, '$');
		if (p == NULL)
			break;
		buffer_puts(bf, str, (size_t)(p - str));
		vs = &p[1];
		if (*vs != '{') {
			log_warnx(ic->ic_path, ic->ic_lno,
			    "invalid substitution, expected '{'");
			error = 1;
			break;
		}
		vs += 1;
		ve = strchr(vs, '}');
		if (ve == NULL) {
			log_warnx(ic->ic_path, ic->ic_lno,
			    "invalid substitution, expected '}'");
			error = 1;
			break;
		}
		len = (size_t)(ve - vs);
		if (len == 0) {
			log_warnx(ic->ic_path, ic->ic_lno,
			    "invalid substitution, empty variable name");
			error = 1;
			break;
		}

		name = estrndup(vs, len);
		lookup = ic->ic_arg->lookup(name, ic->ic_arg->arg);
		free(name);
		if (lookup == NULL) {
			log_warnx(ic->ic_path, ic->ic_lno,
			    "invalid substitution, unknown variable '%.*s'",
			    (int)len, vs);
			error = 1;
			break;
		}
		error = interpolate(ic, bf, lookup);
		free(lookup);
		if (error)
			break;
		str = &ve[1];
	}
	ic->ic_depth--;
	/* Output any remaining tail. */
	buffer_puts(bf, str, strlen(str));
	return error;
}
