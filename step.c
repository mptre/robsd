#include "step.h"

#include "config.h"

#include <err.h>
#include <inttypes.h>
#include <limits.h>	/* LLONG_MIN, LLONG_MAX */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "libks/buffer.h"
#include "libks/vector.h"

#include "alloc.h"
#include "interpolate.h"
#include "lexer.h"
#include "token.h"

enum token_type {
	TOKEN_COMMA,
	TOKEN_VALUE,
	TOKEN_NEWLINE,
};

struct step_file {
	struct buffer		*bf;
	VECTOR(const char *)	 columns;
	VECTOR(struct step)	 steps;
};

static int	steps_parse_header(struct step_file *, struct lexer *);
static int	steps_parse_row(struct step_file *, struct lexer *);

static struct token	*step_lexer_read(struct lexer *, void *);
static const char	*token_serialize(const struct token *);

enum step_field_type {
	UNKNOWN,
	STRING,
	INTEGER,
};

struct step_field {
	enum step_field_type	sf_type;
	union step_value	sf_val;
};

static int	step_field_is_empty(const struct step_field *);
static int	step_field_set(struct step_field *, enum step_field_type,
    const char *);

static int	step_cmp(const struct step *, const struct step *);
static int	step_set_field(struct step *, const char *, const char *);
static int	step_validate(const struct step *, struct lexer *, int);

struct field_definition {
	const char		*fd_name;
	enum step_field_type	 fd_type;
	unsigned int		 fd_index;
	unsigned int		 fd_flags;
#define OPTIONAL	0x00000001u

	struct {
		const char	*str;
	} fd_default;
};

static const struct field_definition	*field_definition_find_by_name(
    const char *);

static const struct field_definition fields[] = {
	{ "step",	INTEGER,	0, 0,		{ 0 } },
	{ "name",	STRING,		1, 0,		{ 0 } },
	{ "exit",	INTEGER,	2, 0,		{ 0 } },
	{ "duration",	INTEGER,	3, 0,		{ 0 } },
	{ "delta",	INTEGER,	4, OPTIONAL,	{ "0" } },
	{ "log",	STRING,		5, OPTIONAL,	{ "" } },
	{ "user",	STRING,		6, 0,		{ 0 } },
	{ "time",	INTEGER,	7, 0,		{ 0 } },
	{ "skip",	INTEGER,	8, OPTIONAL,	{ "0" } },
};
static const size_t nfields = sizeof(fields) / sizeof(fields[0]);

struct step_file *
steps_parse(const char *path)
{
	struct step_file *sf;
	struct lexer *lx;
	int error = 0;

	sf = ecalloc(1, sizeof(*sf));
	sf->bf = buffer_alloc(512);
	if (sf->bf == NULL)
		err(1, NULL);
	if (VECTOR_INIT(sf->columns))
		err(1, NULL);
	if (VECTOR_INIT(sf->steps))
		err(1, NULL);

	lx = lexer_alloc(&(struct lexer_arg){
	    .path	= path,
	    .callbacks	= {
		.read		= step_lexer_read,
		.serialize	= token_serialize,
		.arg		= sf,
	    },
	});
	if (lx == NULL) {
		error = 1;
		goto out;
	}

	if (steps_parse_header(sf, lx)) {
		error = 1;
		goto out;
	}

	for (;;) {
		if (lexer_peek(lx, LEXER_EOF))
			break;
		error = steps_parse_row(sf, lx);
		if (error)
			break;
	}

out:
	lexer_free(lx);
	if (error) {
		steps_free(sf);
		sf = NULL;
	}
	return sf;
}

void
steps_free(struct step_file *sf)
{
	if (sf == NULL)
		return;

	buffer_free(sf->bf);
	VECTOR_FREE(sf->columns);

	while (!VECTOR_EMPTY(sf->steps)) {
		struct step *st;
		size_t i;

		st = VECTOR_POP(sf->steps);
		for (i = 0; i < VECTOR_LENGTH(st->st_fields); i++) {
			struct step_field *field = &st->st_fields[i];

			switch (field->sf_type) {
			case UNKNOWN:
			case INTEGER:
				break;

			case STRING:
				free(field->sf_val.str);
				break;
			}
		}
		VECTOR_FREE(st->st_fields);
	}
	VECTOR_FREE(sf->steps);

	free(sf);
}

struct step *
steps_get(struct step_file *step_file)
{
	return step_file->steps;
}

struct step *
steps_alloc(struct step_file *sf)
{
	struct step *st;

	st = VECTOR_CALLOC(sf->steps);
	if (st == NULL)
		err(1, NULL);
	return st;
}

void
steps_sort(struct step *steps)
{
	VECTOR_SORT(steps, step_cmp);
}

struct step *
steps_find_by_name(struct step *steps, const char *name)
{
	const struct field_definition *fd;
	size_t i;

	fd = field_definition_find_by_name("name");
	for (i = 0; i < VECTOR_LENGTH(steps); i++) {
		struct step *st = &steps[i];
		const struct step_field *sf = &st->st_fields[fd->fd_index];

		if (!step_field_is_empty(sf) &&
		    strcmp(sf->sf_val.str, name) == 0)
			return st;
	}
	return NULL;
}

struct step *
steps_find_by_id(struct step *steps, int id)
{
	const struct field_definition *fd;
	size_t i;

	fd = field_definition_find_by_name("step");
	for (i = 0; i < VECTOR_LENGTH(steps); i++) {
		struct step *st = &steps[i];
		const struct step_field *sf = &st->st_fields[fd->fd_index];

		if (!step_field_is_empty(sf) && sf->sf_val.integer == id)
			return st;
	}
	return NULL;
}

void
steps_header(struct buffer *bf)
{
	size_t i;

	for (i = 0; i < nfields; i++) {
		if (i > 0)
			buffer_putc(bf, ',');
		buffer_printf(bf, "%s", fields[i].fd_name);
	}
	buffer_putc(bf, '\n');
}

int
step_init(struct step *st)
{
	size_t i;

	if (VECTOR_INIT(st->st_fields))
		err(1, NULL);
	for (i = 0; i < nfields; i++) {
		if (VECTOR_CALLOC(st->st_fields) == NULL)
			err(1, NULL);
	}

	for (i = 0; i < nfields; i++) {
		const struct field_definition *fd = &fields[i];

		if ((fd->fd_flags & OPTIONAL) == 0)
			continue;

		if (step_set_field(st, fd->fd_name, fd->fd_default.str))
			return 1;
	}
	return 0;
}

char *
step_interpolate_lookup(const char *name, void *arg)
{
	struct buffer *bf;
	const struct field_definition *fd;
	const struct step *st = (struct step *)arg;
	const struct step_field *sf;
	char *val = NULL;

	fd = field_definition_find_by_name(name);
	if (fd == NULL)
		return NULL;
	sf = &st->st_fields[fd->fd_index];

	bf = buffer_alloc(128);
	if (bf == NULL)
		err(1, NULL);
	switch (sf->sf_type) {
	case UNKNOWN:
		goto out;
	case STRING:
		buffer_printf(bf, "%s", sf->sf_val.str);
		break;
	case INTEGER:
		buffer_printf(bf, "%" PRId64, sf->sf_val.integer);
		break;
	}
	val = buffer_release(bf);
out:
	buffer_free(bf);
	return val;
}

int
step_serialize(const struct step *st, struct buffer *bf)
{
	struct buffer *fmt;
	size_t i;
	int error;

	fmt = buffer_alloc(1024);
	if (fmt == NULL)
		err(1, NULL);
	for (i = 0; i < nfields; i++) {
		if (i > 0)
			buffer_putc(fmt, ',');
		buffer_printf(fmt, "${%s}", fields[i].fd_name);
	}
	buffer_putc(fmt, '\n');
	buffer_putc(fmt, '\0');

	error = interpolate_buffer(buffer_get_ptr(fmt), bf,
	    &(struct interpolate_arg){
		.lookup	= step_interpolate_lookup,
		.arg	= (void *)st,
	});
	buffer_free(fmt);
	return error;
}

const union step_value *
step_get_field(const struct step *st, const char *name)
{
	const struct field_definition *fd;

	fd = field_definition_find_by_name(name);
	if (fd == NULL)
		return NULL;
	return &st->st_fields[fd->fd_index].sf_val;
}

int
step_set_keyval(struct step *st, const char *kv)
{
	const char *val;
	char *key;
	size_t keylen;
	int error = 0;

	val = strchr(kv, '=');
	if (val == NULL) {
		warnx("missing field separator in '%s'", kv);
		return 1;
	}
	keylen = (size_t)(val - kv);
	key = estrndup(kv, keylen);
	val++; /* consume '=' */

	if (step_set_field(st, key, val)) {
		warnx("unknown key '%s'", key);
		error = 1;
	}
	free(key);
	return error;
}

static int
step_field_is_empty(const struct step_field *sf)
{
	switch (sf->sf_type) {
	case STRING:
	case INTEGER:
		return 0;
	case UNKNOWN:
		break;
	}
	return 1;
}

static int
step_field_set(struct step_field *sf, enum step_field_type type,
    const char *val)
{
	switch (type) {
	case STRING:
		free(sf->sf_val.str);
		sf->sf_val.str = estrdup(val);
		break;

	case INTEGER: {
		const char *errstr;
		int64_t v;

		v = strtonum(val, LLONG_MIN, LLONG_MAX, &errstr);
		if (errstr != NULL) {
			warnx("value %s %s", val, errstr);
			return 1;
		}
		sf->sf_val.integer = v;
		break;
	}

	case UNKNOWN:
		return 1;
	}
	sf->sf_type = type;
	return 0;
}

static int
steps_parse_header(struct step_file *sf, struct lexer *lx)
{
	if (lexer_peek(lx, LEXER_EOF))
		return 0;

	for (;;) {
		struct token *col, *discard;
		const char **dst;

		if (!lexer_expect(lx, TOKEN_VALUE, &col))
			return 1;
		dst = VECTOR_ALLOC(sf->columns);
		if (dst == NULL)
			err(1, NULL);
		*dst = col->tk_str;

		if (lexer_if(lx, TOKEN_NEWLINE, &discard))
			break;
		if (!lexer_expect(lx, TOKEN_COMMA, &discard))
			return 1;
	}
	return 0;
}

static int
steps_parse_row(struct step_file *sf, struct lexer *lx)
{
	struct step *st;
	size_t col = 0;
	int lno = 0;

	st = VECTOR_CALLOC(sf->steps);
	if (st == NULL)
		err(1, NULL);
	if (step_init(st))
		return 1;

	for (;; col++) {
		struct token *discard, *val;
		const char *key;

		if (lexer_if(lx, TOKEN_COMMA, &discard))
			continue;

		if (!lexer_expect(lx, TOKEN_VALUE, &val))
			return 1;
		if (lno == 0)
			lno = val->tk_lno;

		if (col >= VECTOR_LENGTH(sf->columns)) {
			lexer_warnx(lx, val->tk_lno, "unknown column %zu", col);
			return 1;
		}

		key = sf->columns[col];
		if (field_definition_find_by_name(key) == NULL) {
			lexer_warnx(lx, val->tk_lno, "unknown field '%s'", key);
			return 1;
		}
		if (step_set_field(st, key, val->tk_str))
			return 1;

		if (lexer_if(lx, TOKEN_NEWLINE, &discard))
			break;
		if (!lexer_expect(lx, TOKEN_COMMA, &discard))
			return 1;
	}

	return step_validate(st, lx, lno);
}

static struct token *
step_lexer_read(struct lexer *lx, void *arg)
{
	struct lexer_state s;
	struct step_file *sf = (struct step_file *)arg;
	struct buffer *bf = sf->bf;
	struct token *tk;
	char ch;

	s = lexer_get_state(lx);

	if (lexer_getc(lx, &ch))
		return NULL;
	if (ch == 0)
		return lexer_emit(lx, &s, LEXER_EOF);
	if (ch == ',')
		return lexer_emit(lx, &s, TOKEN_COMMA);
	if (ch == '\n')
		return lexer_emit(lx, &s, TOKEN_NEWLINE);

	buffer_reset(bf);
	for (;;) {
		buffer_putc(bf, ch);
		if (lexer_getc(lx, &ch))
			return NULL;
		if (ch == 0) {
			lexer_warnx(lx, s.lno, "unterminated value");
			return NULL;
		}
		if (ch == ',' || ch == '\n')
			break;
	}
	lexer_ungetc(lx, ch);
	buffer_putc(bf, '\0');
	tk = lexer_emit(lx, &s, TOKEN_VALUE);
	tk->tk_str = estrdup(buffer_get_ptr(bf));
	return tk;
}

static const char *
token_serialize(const struct token *tk)
{
	enum token_type type = (enum token_type)tk->tk_type;

	switch (type) {
	case TOKEN_COMMA:
		return "COMMA";
	case TOKEN_VALUE:
		return "VALUE";
	case TOKEN_NEWLINE:
		return "NEWLINE";
	}
	return "UNKNOWN";
}

static int
step_cmp(const struct step *a, const struct step *b)
{
	const struct field_definition *fd;

	fd = field_definition_find_by_name("step");
	if (a->st_fields[fd->fd_index].sf_val.integer <
	    b->st_fields[fd->fd_index].sf_val.integer)
		return -1;
	if (a->st_fields[fd->fd_index].sf_val.integer >
	    b->st_fields[fd->fd_index].sf_val.integer)
		return 1;
	return 0;
}

static int
step_set_field(struct step *st, const char *name, const char *val)
{
	const struct field_definition *fd;

	fd = field_definition_find_by_name(name);
	if (fd == NULL)
		return 1;
	return step_field_set(&st->st_fields[fd->fd_index], fd->fd_type, val);
}

int
step_set_field_integer(struct step *st, const char *name, int val)
{
	const struct field_definition *fd;

	fd = field_definition_find_by_name(name);
	if (fd == NULL)
		return 1;
	st->st_fields[fd->fd_index].sf_type = INTEGER;
	st->st_fields[fd->fd_index].sf_val.integer = val;
	return 0;
}

static int
step_validate(const struct step *st, struct lexer *lx, int lno)
{
	size_t i;
	int error = 0;

	for (i = 0; i < nfields; i++) {
		const struct field_definition *fd = &fields[i];

		if (fd->fd_flags & OPTIONAL)
			continue;

		if (step_field_is_empty(&st->st_fields[fd->fd_index])) {
			lexer_warnx(lx, lno, "missing field '%s'",
			    fd->fd_name);
			error = 1;
		}
	}
	return error;
}

static const struct field_definition *
field_definition_find_by_name(const char *name)
{
	size_t i;

	for (i = 0; i < nfields; i++) {
		if (strcmp(fields[i].fd_name, name) == 0)
			return &fields[i];
	}
	return NULL;
}
