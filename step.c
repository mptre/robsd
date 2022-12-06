#include "step.h"

#include "config.h"

#include <err.h>
#include <errno.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "buffer.h"
#include "cdefs.h"
#include "interpolate.h"
#include "lexer.h"
#include "token.h"
#include "vector.h"

enum token_type {
	TOKEN_COMMA,
	TOKEN_VALUE,
	TOKEN_NEWLINE,
};

struct parser_context {
	struct buffer		*pc_bf;
	VECTOR(const char *)	 pc_columns;
	VECTOR(struct step)	 pc_steps;
};

static void	parser_context_init(struct parser_context *);
static void	parser_context_reset(struct parser_context *);

static int	steps_parse_header(struct parser_context *, struct lexer *);
static int	steps_parse_row(struct parser_context *, struct lexer *);

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

static int	step_cmp(const void *, const void *);
static int	step_set_field(struct step *, const char *, const char *);
static int	step_validate(const struct step *, struct lexer *, int);

struct field_definition {
	const char	*fd_name;
	int		 fd_type;
	unsigned int	 fd_index;
	unsigned int	 fd_flags;
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
	{ "log",	STRING,		4, OPTIONAL,	{ "" } },
	{ "user",	STRING,		5, 0,		{ 0 } },
	{ "time",	INTEGER,	6, 0,		{ 0 } },
	{ "skip",	INTEGER,	7, OPTIONAL,	{ "0" } },
};
static const size_t nfields = sizeof(fields) / sizeof(fields[0]);

struct step *
steps_parse(const char *path)
{
	struct parser_context pc;
	struct lexer *lx;
	struct step *steps = NULL;
	int error = 0;

	parser_context_init(&pc);
	lx = lexer_alloc(&(struct lexer_arg){
		.path		= path,
		.callbacks	= {
			.read		= step_lexer_read,
			.serialize	= token_serialize,
			.arg		= &pc,
		},
	});
	if (lx == NULL) {
		error = 1;
		goto out;
	}

	if (steps_parse_header(&pc, lx)) {
		error = 1;
		goto out;
	}

	for (;;) {
		if (lexer_peek(lx, LEXER_EOF))
			break;
		error = steps_parse_row(&pc, lx);
		if (error)
			break;
	}

out:
	if (error == 0) {
		steps = pc.pc_steps;
		pc.pc_steps = NULL;
	}
	lexer_free(lx);
	parser_context_reset(&pc);
	return steps;
}

void
steps_free(struct step *steps)
{
	if (steps == NULL)
		return;

	while (!VECTOR_EMPTY(steps)) {
		struct step *st;
		size_t i;

		st = VECTOR_POP(steps);
		for (i = 0; i < VECTOR_LENGTH(st->st_fields); i++) {
			struct step_field *sf = &st->st_fields[i];

			switch (sf->sf_type) {
			case UNKNOWN:
			case INTEGER:
				break;

			case STRING:
				free(sf->sf_val.str);
				break;
			}
		}
		VECTOR_FREE(st->st_fields);
	}
	VECTOR_FREE(steps);
}

void
steps_sort(struct step *steps)
{
	size_t nsteps = VECTOR_LENGTH(steps);

	if (nsteps > 0)
		qsort(steps, nsteps, sizeof(*steps), step_cmp);
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

	if (VECTOR_INIT(st->st_fields) == NULL)
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
	char buf[64];
	ssize_t buflen = sizeof(buf);
	const struct field_definition *fd;
	const struct step *st = (struct step *)arg;
	const struct step_field *sf;
	const char *val = NULL;
	char *str;

	fd = field_definition_find_by_name(name);
	if (fd == NULL)
		return NULL;
	sf = &st->st_fields[fd->fd_index];
	switch (sf->sf_type) {
	case UNKNOWN:
		return NULL;

	case STRING:
		val = sf->sf_val.str;
		break;

	case INTEGER: {
		int n;

		n = snprintf(buf, buflen, "%" PRId64, sf->sf_val.integer);
		if (n < 0 || n >= buflen) {
			warnx("id buffer too small");
			return NULL;
		}
		val = buf;
		break;
	}
	}

	str = strdup(val);
	if (str == NULL)
		err(1, NULL);
	return str;
}

int
step_serialize(const struct step *st, struct buffer *bf)
{
	struct buffer *fmt;
	size_t i;
	int error;

	fmt = buffer_alloc(1024);
	for (i = 0; i < nfields; i++) {
		if (i > 0)
			buffer_putc(fmt, ',');
		buffer_printf(fmt, "${%s}", fields[i].fd_name);
	}
	buffer_putc(fmt, '\n');
	buffer_putc(fmt, '\0');

	error = interpolate_buffer(fmt->bf_ptr, bf,
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
	int error = 0;

	val = strchr(kv, '=');
	if (val == NULL) {
		warnx("missing field separator in '%s'", kv);
		return 1;
	}
	key = strndup(kv, val - kv);
	if (key == NULL)
		err(1, NULL);
	val++; /* consume '=' */

	if (step_set_field(st, key, val)) {
		warnx("unknown key '%s'", key);
		error = 1;
	}
	free(key);
	return error;
}

static void
parser_context_init(struct parser_context *pc)
{
	pc->pc_bf = buffer_alloc(512);
	if (VECTOR_INIT(pc->pc_columns) == NULL)
		err(1, NULL);
	if (VECTOR_INIT(pc->pc_steps) == NULL)
		err(1, NULL);
}

static void
parser_context_reset(struct parser_context *pc)
{
	buffer_free(pc->pc_bf);
	VECTOR_FREE(pc->pc_columns);
	steps_free(pc->pc_steps);
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
		sf->sf_val.str = strdup(val);
		if (sf->sf_val.str == NULL)
			err(1, NULL);
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
steps_parse_header(struct parser_context *pc, struct lexer *lx)
{
	if (lexer_peek(lx, LEXER_EOF))
		return 0;

	for (;;) {
		struct token *col, *discard;
		const char **dst;

		if (!lexer_expect(lx, TOKEN_VALUE, &col))
			return 1;
		dst = VECTOR_ALLOC(pc->pc_columns);
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
steps_parse_row(struct parser_context *pc, struct lexer *lx)
{
	struct step *st;
	size_t col = 0;
	int lno = 0;

	st = VECTOR_CALLOC(pc->pc_steps);
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

		if (col >= VECTOR_LENGTH(pc->pc_columns)) {
			lexer_warnx(lx, val->tk_lno, "unknown column %zu", col);
			return 1;
		}

		key = pc->pc_columns[col];
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
	struct parser_context *pc = (struct parser_context *)arg;
	struct buffer *bf = pc->pc_bf;
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
	tk->tk_str = strdup(bf->bf_ptr);
	if (tk->tk_str == NULL)
		err(1, NULL);
	return tk;
}

static const char *
token_serialize(const struct token *tk)
{
	enum token_type type = tk->tk_type;

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
step_cmp(const void *p1, const void *p2)
{
	const struct field_definition *fd;
	const struct step *s1 = p1;
	const struct step *s2 = p2;

	fd = field_definition_find_by_name("step");
	if (s1->st_fields[fd->fd_index].sf_val.integer <
	    s2->st_fields[fd->fd_index].sf_val.integer)
		return -1;
	if (s1->st_fields[fd->fd_index].sf_val.integer >
	    s2->st_fields[fd->fd_index].sf_val.integer)
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
