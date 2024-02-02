#include "interpolate.h"

#include "config.h"

#include <err.h>
#include <string.h>

#include "libks/arena-buffer.h"
#include "libks/arena.h"
#include "libks/buffer.h"

#include "log.h"

struct interpolate_context {
	const struct interpolate_arg	*arg;
	const char			*path;
	int				 lno;
	int				 depth;
	unsigned int			 flags;
};

static int	interpolate(struct interpolate_context *, struct buffer *,
    const char *);

const char *
interpolate_file(const char *path, const struct interpolate_arg *arg)
{
	struct interpolate_context c = {
		.arg	= arg,
		.path	= path,
		.lno	= arg->lno,
		.flags	= arg->flags,
	};
	struct buffer_getline it = {0};
	struct buffer *bf, *out;
	const char *line;
	int error = 0;

	arena_scope(arg->scratch, s);

	bf = arena_buffer_read(&s, path);
	if (bf == NULL) {
		warn("%s", path);
		return NULL;
	}

	out = arena_buffer_alloc(c.arg->eternal, 1 << 10);
	while ((line = buffer_getline(bf, &it)) != NULL) {
		c.lno++;
		if (interpolate(&c, out, line)) {
			error = 1;
			break;
		}
		buffer_putc(out, '\n');
	}
	buffer_getline_free(&it);

	return error == 0 ? buffer_str(out) : NULL;
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
	struct interpolate_context c = {
		.arg	= arg,
		.lno	= arg->lno,
		.flags	= arg->flags,
	};
	int error;

	error = interpolate(&c, bf, str);
	return error;
}

static int
interpolate(struct interpolate_context *c, struct buffer *bf,
    const char *str)
{
	int error = 0;

	if (++c->depth == 5) {
		log_warnx(c->path, c->lno,
		    "invalid substitution, recursion too deep");
		return 1;
	}

	arena_scope(c->arg->scratch, s);

	for (;;) {
		const char *lookup, *name, *p, *ve, *vs;
		size_t len;

		p = strchr(str, '$');
		if (p == NULL)
			break;
		buffer_puts(bf, str, (size_t)(p - str));
		vs = &p[1];
		if (*vs != '{') {
			log_warnx(c->path, c->lno,
			    "invalid substitution, expected '{'");
			error = 1;
			break;
		}
		vs += 1;
		ve = strchr(vs, '}');
		if (ve == NULL) {
			log_warnx(c->path, c->lno,
			    "invalid substitution, expected '}'");
			error = 1;
			break;
		}
		len = (size_t)(ve - vs);
		if (len == 0) {
			log_warnx(c->path, c->lno,
			    "invalid substitution, empty variable name");
			error = 1;
			break;
		}

		name = arena_strndup(&s, vs, len);
		lookup = c->arg->lookup(name, &s, c->arg->arg);
		if (lookup == NULL &&
		    (c->flags & INTERPOLATE_IGNORE_LOOKUP_ERRORS)) {
			buffer_puts(bf, p, (size_t)(ve - p + 1));
			goto next;
		}
		if (lookup == NULL) {
			log_warnx(c->path, c->lno,
			    "invalid substitution, unknown variable '%.*s'",
			    (int)len, vs);
			error = 1;
			break;
		}
		error = interpolate(c, bf, lookup);
		if (error)
			break;

next:
		str = &ve[1];
	}
	c->depth--;
	/* Output any remaining tail. */
	buffer_puts(bf, str, strlen(str));
	return error;
}
