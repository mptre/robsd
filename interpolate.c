#include "interpolate.h"

#include "config.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "libks/arena-buffer.h"
#include "libks/arena.h"
#include "libks/buffer.h"

#include "log.h"

struct interpolate_context {
	const struct interpolate_arg	*ic_arg;
	const char			*ic_path;
	int				 ic_lno;
	int				 ic_depth;
	unsigned int			 ic_flags;
};

static int	interpolate(struct interpolate_context *, struct buffer *,
    const char *);

const char *
interpolate_file(const char *path, const struct interpolate_arg *arg)
{
	struct interpolate_context ic = {
		.ic_arg		= arg,
		.ic_path	= path,
		.ic_lno		= arg->lno,
		.ic_flags	= arg->flags,
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

	bf = arena_buffer_alloc(ic.ic_arg->eternal, 1 << 10);
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
	if (error == 0)
		buf = buffer_str(bf);
	buffer_free(bf);
	free(line);
	fclose(fh);
	return buf;
}

const char *
interpolate_str(const char *str, const struct interpolate_arg *arg)
{
	struct buffer *bf;

	bf = arena_buffer_alloc(arg->eternal, 1 << 10);
	if (interpolate_buffer(str, bf, arg))
		return NULL;
	return buffer_str(bf);
}

int
interpolate_buffer(const char *str, struct buffer *bf,
    const struct interpolate_arg *arg)
{
	struct interpolate_context ic = {
		.ic_arg		= arg,
		.ic_lno		= arg->lno,
		.ic_flags	= arg->flags,
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

	if (++ic->ic_depth == 5) {
		log_warnx(ic->ic_path, ic->ic_lno,
		    "invalid substitution, recursion too deep");
		return 1;
	}

	arena_scope(ic->ic_arg->scratch, s);

	for (;;) {
		const char *lookup, *name, *p, *ve, *vs;
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

		name = arena_strndup(&s, vs, len);
		lookup = ic->ic_arg->lookup(name, &s, ic->ic_arg->arg);
		if (lookup == NULL &&
		    (ic->ic_flags & INTERPOLATE_IGNORE_LOOKUP_ERRORS)) {
			buffer_puts(bf, p, (size_t)(ve - p + 1));
			goto next;
		}
		if (lookup == NULL) {
			log_warnx(ic->ic_path, ic->ic_lno,
			    "invalid substitution, unknown variable '%.*s'",
			    (int)len, vs);
			error = 1;
			break;
		}
		error = interpolate(ic, bf, lookup);
		if (error)
			break;

next:
		str = &ve[1];
	}
	ic->ic_depth--;
	/* Output any remaining tail. */
	buffer_puts(bf, str, strlen(str));
	return error;
}
