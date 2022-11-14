#include "interpolate.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <util.h>

#include "buffer.h"

struct interpolate_context {
	const struct interpolate_arg	*ic_arg;
	const char			*ic_path;
	int				 ic_lno;
	struct buffer			*ic_bf;
};

static void	interpolate_context_init(struct interpolate_context *,
    const struct interpolate_arg *, const char *);
static void	interpolate_context_reset(struct interpolate_context *);

static int	interpolate(struct interpolate_context *, const char *);

char *
interpolate_file(const char *path, const struct interpolate_arg *arg)
{
	struct interpolate_context ic;
	FILE *fh;
	char *buf = NULL;
	char *line = NULL;
	size_t linesiz = 0;
	int error = 0;

	fh = fopen(path, "r");
	if (fh == NULL) {
		warn("open: %s", path);
		return NULL;
	}

	interpolate_context_init(&ic, arg, path);

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
		if (interpolate(&ic, line)) {
			error = 1;
			break;
		}
	}
	if (error == 0) {
		buffer_putc(ic.ic_bf, '\0');
		buf = buffer_release(ic.ic_bf);
	}

	free(line);
	interpolate_context_reset(&ic);
	fclose(fh);
	return buf;
}

char *
interpolate_str(const char *str, const struct interpolate_arg *arg)
{
	struct interpolate_context ic;
	char *buf = NULL;

	interpolate_context_init(&ic, arg, NULL);
	if (interpolate(&ic, str) == 0) {
		buffer_putc(ic.ic_bf, '\0');
		buf = buffer_release(ic.ic_bf);
	}
	interpolate_context_reset(&ic);
	return buf;
}

static void
interpolate_context_init(struct interpolate_context *ic,
    const struct interpolate_arg *ia, const char *path)
{
	ic->ic_arg = ia;
	ic->ic_path = path;
	ic->ic_lno = ia->lno;
	ic->ic_bf = buffer_alloc(1024);
	if (ic->ic_bf == NULL)
		err(1, NULL);
}

static void
interpolate_context_reset(struct interpolate_context *ic)
{
	buffer_free(ic->ic_bf);
}

static int
interpolate(struct interpolate_context *ic, const char *str)
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

		name = strndup(vs, len);
		if (name == NULL)
			err(1, NULL);
		lookup = ic->ic_arg->lookup(name, ic->ic_arg->arg);
		free(name);
		if (lookup == NULL) {
			log_warnx(ic->ic_path, ic->ic_lno,
			    "invalid substitution, unknown variable '%.*s'",
			    (int)len, vs);
			return 1;
		}
		rep = interpolate_str(lookup, ic->ic_arg);
		buffer_puts(ic->ic_bf, str, p - str);
		buffer_puts(ic->ic_bf, rep, strlen(rep));
		free(rep);
		free(lookup);
		str = &ve[1];
	}
	/* Output any remaining tail. */
	buffer_puts(ic->ic_bf, str, strlen(str));

	return 0;
}
