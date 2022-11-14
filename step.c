#include "step.h"

#include "config.h"

#include <ctype.h>
#include <err.h>
#include <errno.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "buffer.h"
#include "cdefs.h"
#include "interpolate.h"
#include "lexer.h"
#include "token.h"
#include "vector.h"

enum token_type {
	TOKEN_KEY,
	TOKEN_EQUAL,
	TOKEN_STRING,
	TOKEN_NEWLINE,
};

struct parser_context {
	struct buffer		*pc_bf;
	VECTOR(struct step)	 pc_steps;
};

static void	parser_context_init(struct parser_context *);
static void	parser_context_reset(struct parser_context *);

static int	steps_parse_line(struct parser_context *, struct lexer *);

static struct token	*step_lexer_read(struct lexer *, void *);
static const char	*token_serialize(const struct token *);

static int	  step_cmp(const void *, const void *);
static int	  step_validate(const struct step *, struct lexer *, int);
static char	**step_value(struct step *, const char *);

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

	for (;;) {
		if (lexer_peek(lx, LEXER_EOF))
			break;
		error = steps_parse_line(&pc, lx);
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

		st = VECTOR_POP(steps);
		free(st->st_duration);
		free(st->st_exit);
		free(st->st_log);
		free(st->st_name);
		free(st->st_step);
		free(st->st_time);
		free(st->st_user);
		free(st->st_skip);
	}
	VECTOR_FREE(steps);
}

int
steps_sort(struct step *steps)
{
	size_t nsteps = VECTOR_LENGTH(steps);
	size_t i;

	for (i = 0; i < nsteps; i++) {
		struct step *st = &steps[i];
		const char *errstr;
		int id;

		id = strtonum(st->st_step, 1, INT_MAX, &errstr);
		if (id == 0) {
			warnx("step %s %s", st->st_step, errstr);
			return 1;
		}
		st->st_id = id;
	}

	if (nsteps > 0)
		qsort(steps, nsteps, sizeof(*steps), step_cmp);
	return 0;
}

struct step *
steps_find_by_name(struct step *steps, const char *name)
{
	size_t i;

	for (i = 0; i < VECTOR_LENGTH(steps); i++) {
		struct step *st = &steps[i];

		if (strcmp(st->st_name, name) == 0)
			return st;
	}
	return NULL;
}

char *
step_interpolate_lookup(const char *name, void *arg)
{
	struct step *st = (struct step *)arg;
	char **val;
	char *p;

	val = step_value(st, name);
	if (val == NULL || *val == NULL)
		return NULL;

	p = strdup(*val);
	if (p == NULL)
		err(1, NULL);
	return p;
}

int
step_serialize(const struct step *st, struct buffer *bf)
{
	static const char fmt[] = ""
	    "step=\"${step}\" "
	    "name=\"${name}\" "
	    "exit=\"${exit}\" "
	    "duration=\"${duration}\" "
	    "log=\"${log}\" "
	    "user=\"${user}\" "
	    "time=\"${time}\" "
	    "skip=\"${skip}\"\n";

	return interpolate_buffer(fmt, bf,
	    &(struct interpolate_arg){
		.lookup	= step_interpolate_lookup,
		.arg	= (void *)st,
	});
}

int
step_set_defaults(struct step *st)
{
	if (st->st_time == NULL) {
		char buf[128];
		struct timespec ts;
		uint64_t seconds;

		if (clock_gettime(CLOCK_REALTIME, &ts) == -1) {
			warn("clock_gettime");
			return 1;
		}
		seconds = ts.tv_sec + ts.tv_nsec / 1000000000;
		(void)snprintf(buf, sizeof(buf), "%" PRIu64, seconds);
		if (step_set_field(st, "time", buf))
			return 1;
	}

	if (st->st_skip == NULL) {
		if (step_set_field(st, "skip", "0"))
			return 1;
	}

	return 0;
}

int
step_set_field(struct step *st, const char *key, const char *val)
{
	char **dst;

	dst = step_value(st, key);
	if (dst == NULL)
		return 1;
	if (*dst != NULL)
		free(*dst);
	*dst = strdup(val);
	if (*dst == NULL)
		err(1, NULL);
	return 0;
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
	if (VECTOR_INIT(pc->pc_steps) == NULL)
		err(1, NULL);
}

static void
parser_context_reset(struct parser_context *pc)
{
	buffer_free(pc->pc_bf);
	steps_free(pc->pc_steps);
}

static int
steps_parse_line(struct parser_context *pc, struct lexer *lx)
{
	struct step *st;
	int error = 0;
	int lno = 0;

	st = VECTOR_CALLOC(pc->pc_steps);
	if (st == NULL)
		err(1, NULL);

	for (;;) {
		struct token *discard, *key, *val;

		if (!lexer_expect(lx, TOKEN_KEY, &key)) {
			error = 1;
			break;
		}
		if (!lexer_expect(lx, TOKEN_EQUAL, &discard)) {
			error = 1;
			break;
		}
		if (!lexer_expect(lx, TOKEN_STRING, &val)) {
			error = 1;
			break;
		}

		if (lno == 0)
			lno = key->tk_lno;

		if (step_set_field(st, key->tk_str, val->tk_str)) {
			lexer_warnx(lx, key->tk_lno, "unknown key '%s'",
			    key->tk_str);
			error = 1;
		}

		if (lexer_if(lx, TOKEN_NEWLINE, &discard))
			break;
	}
	if (error == 0)
		error = step_validate(st, lx, lno);

	return error;
}

static struct token *
step_lexer_read(struct lexer *lx, void *arg)
{
	struct lexer_state s;
	struct parser_context *pc = (struct parser_context *)arg;
	struct buffer *bf = pc->pc_bf;
	struct token *tk;
	char ch;

	do {
		if (lexer_getc(lx, &ch))
			return NULL;
	} while (ch == ' ' || ch == '\t');

	s = lexer_get_state(lx);

	if (ch == 0)
		return lexer_emit(lx, &s, LEXER_EOF);

	if (ch == '=')
		return lexer_emit(lx, &s, TOKEN_EQUAL);

	buffer_reset(bf);

	if (ch == '"') {
		for (;;) {
			if (lexer_getc(lx, &ch))
				return NULL;
			if (ch == 0) {
				lexer_warnx(lx, s.lno, "unterminated string");
				return NULL;
			}
			if (ch == '"')
				break;
			buffer_putc(bf, ch);
		}
		if (bf->bf_len == 0)
			lexer_warnx(lx, s.lno, "empty string");
		buffer_putc(bf, '\0');

		tk = lexer_emit(lx, &s, TOKEN_STRING);
		tk->tk_str = strdup(bf->bf_ptr);
		if (tk->tk_str == NULL)
			err(1, NULL);
		return tk;
	}

	if (ch == '\n')
		return lexer_emit(lx, &s, TOKEN_NEWLINE);

	do {
		buffer_putc(bf, ch);
		if (lexer_getc(lx, &ch))
			return NULL;
	} while (islower((unsigned char)ch));
	lexer_ungetc(lx, ch);
	buffer_putc(bf, '\0');

	tk = lexer_emit(lx, &s, TOKEN_KEY);
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
	case TOKEN_KEY:
		return "KEY";
	case TOKEN_EQUAL:
		return "EQUAL";
	case TOKEN_STRING:
		return "STRING";
	case TOKEN_NEWLINE:
		return "NEWLINE";
	}
	return "UNKNOWN";
}

static int
step_cmp(const void *p1, const void *p2)
{
	const struct step *s1 = p1;
	const struct step *s2 = p2;

	if (s1->st_id < s2->st_id)
		return -1;
	if (s1->st_id > s2->st_id)
		return 1;
	return 0;
}

static int
step_validate(const struct step *st, struct lexer *lx, int lno)
{
	int error = 0;

	if (st->st_duration == NULL) {
		lexer_warnx(lx, lno, "missing key 'duration'");
		error = 1;
	}
	if (st->st_exit == NULL) {
		lexer_warnx(lx, lno, "missing key 'exit'");
		error = 1;
	}
	if (st->st_log == NULL) {
		lexer_warnx(lx, lno, "missing key 'log'");
		error = 1;
	}
	if (st->st_name == NULL) {
		lexer_warnx(lx, lno, "missing key 'name'");
		error = 1;
	}
	if (st->st_step == NULL) {
		lexer_warnx(lx, lno, "missing key 'step'");
		error = 1;
	}
	if (st->st_time == NULL) {
		lexer_warnx(lx, lno, "missing key 'time'");
		error = 1;
	}
	if (st->st_user == NULL) {
		lexer_warnx(lx, lno, "missing key 'user'");
		error = 1;
	}
	/* skip is optional */

	return error;
}

static char **
step_value(struct step *st, const char *key)
{
	if (strcmp(key, "duration") == 0)
		return &st->st_duration;
	if (strcmp(key, "exit") == 0)
		return &st->st_exit;
	if (strcmp(key, "log") == 0)
		return &st->st_log;
	if (strcmp(key, "name") == 0)
		return &st->st_name;
	if (strcmp(key, "step") == 0)
		return &st->st_step;
	if (strcmp(key, "time") == 0)
		return &st->st_time;
	if (strcmp(key, "user") == 0)
		return &st->st_user;
	if (strcmp(key, "skip") == 0)
		return &st->st_skip;
	return NULL;
}
