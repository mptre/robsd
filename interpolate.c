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
static int	interpolate_inner(struct interpolate_context *, struct buffer *,
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

	arena_scope(arg->scratch, s);

	bf = arena_buffer_read(&s, path);
	if (bf == NULL) {
		warn("%s", path);
		return NULL;
	}

	out = arena_buffer_alloc(c.arg->eternal, 1 << 10);
	while ((line = arena_buffer_getline(&s, bf, &it)) != NULL) {
		c.lno++;
		if (interpolate(&c, out, line))
			return NULL;
		buffer_putc(out, '\n');
	}

	return buffer_str(out);
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

	return interpolate(&c, bf, str);
}

static int
interpolate(struct interpolate_context *c, struct buffer *bf,
    const char *str)
{
	int error;

	if (++c->depth == 5) {
		log_warnx(c->path, c->lno,
		    "invalid substitution, recursion too deep");
		return 1;
	}
	error = interpolate_inner(c, bf, str);
	c->depth--;
	return error;
}

static int
interpolate_inner(struct interpolate_context *c, struct buffer *bf,
    const char *str)
{
	int error = 0;

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
			return 1;
		}
		vs += 1;
		ve = strchr(vs, '}');
		if (ve == NULL) {
			log_warnx(c->path, c->lno,
			    "invalid substitution, expected '}'");
			return 1;
		}
		len = (size_t)(ve - vs);
		if (len == 0) {
			log_warnx(c->path, c->lno,
			    "invalid substitution, empty variable name");
			return 1;
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
			return 1;
		}
		error = interpolate(c, bf, lookup);
		if (error)
			return 1;

next:
		str = &ve[1];
	}
	/* Output any remaining tail. */
	buffer_puts(bf, str, strlen(str));
	return 0;
}
