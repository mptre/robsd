#include "conf.h"

#include "config.h"

#include <sys/param.h>	/* MACHINE, MACHINE_ARCH */
#include <sys/stat.h>

#include <ctype.h>
#include <err.h>
#include <fcntl.h>
#include <fnmatch.h>
#include <glob.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "libks/arena-buffer.h"
#include "libks/arena-vector.h"
#include "libks/arena.h"
#include "libks/arithmetic.h"
#include "libks/buffer.h"
#include "libks/vector.h"

#include "alloc.h"
#include "conf-priv.h"
#include "if.h"
#include "interpolate.h"
#include "lexer.h"
#include "log.h"
#include "token.h"

struct config_lexer_context {
	struct config	*cf;
	struct buffer	*bf;
};

static struct token	*config_lexer_read(struct lexer *, void *);
static const char	*token_serialize(const struct token *);

static const struct grammar	*config_find_grammar_for_keyword(
    const struct config *, const char *);
static const struct grammar	*config_find_grammar_for_interpolation(
    const struct config *, const char *);
static int			 grammar_equals(const struct grammar *,
    const char *);

static int	config_parse1(struct config *);
static int	config_parse_keyword(struct config *, struct token *);
static int	config_validate(const struct config *);

static struct variable	*config_default_build_dir(struct config *,
    const char *);
static struct variable	*config_default_exec_dir(struct config *, const char *);
static struct variable	*config_default_inet4(struct config *, const char *);
static struct variable	*config_default_inet6(struct config *, const char *);
static struct variable	*config_default_ncpu(struct config *, const char *);
static struct variable	*config_default_trace(struct config *, const char *);

static struct variable	*config_append_string(struct config *,
    const char *, const char *);

/* Common configuration shared among all robsd modes. */
static const struct grammar common_grammar[] = {
	{ "arch",		STRING,		NULL,			0,	{ MACHINE_ARCH } },
	{ "build-user",		STRING,		NULL,			0,	{ "build" } },
	{ "builddir",		STRING,		NULL,			FUN,	{ D_FUN(config_default_build_dir) } },
	{ "comment-path",	STRING,		NULL,			0,	{ "${builddir}/comment" } },
	{ "exec-dir",		STRING,		NULL,			FUN,	{ D_FUN(config_default_exec_dir) } },
	{ "hook",		LIST,		config_parse_list,	0,	{ NULL } },
	{ "inet",		STRING,		NULL,			FUN,	{ D_FUN(config_default_inet4) } },
	{ "inet6",		STRING,		NULL,			FUN,	{ D_FUN(config_default_inet6) } },
	{ "keep",		INTEGER,	config_parse_integer,	0,	{ NULL } },
	{ "keep-attic",		INTEGER,	config_parse_boolean,	0,	{ D_I32(1) } },
	{ "keep-dir",		STRING,		NULL,			0,	{ "${robsddir}/attic" } },
	{ "machine",		STRING,		NULL,			0,	{ MACHINE } },
	{ "ncpu",		INTEGER,	NULL,			FUN,	{ D_FUN(config_default_ncpu) } },
	{ "robsddir",		DIRECTORY,	config_parse_directory,	REQ,	{ NULL } },
	{ "skip",		LIST,		config_parse_list,	0,	{ NULL } },
	{ "stat-interval",	INTEGER,	config_parse_integer,	0,	{ D_I32(10) } },
	{ "tmp-dir",		STRING,		NULL,			0,	{ "${builddir}/tmp" } },
	{ "trace",		STRING,		NULL,			FUN,	{ D_FUN(config_default_trace) } },
};

struct config *
config_alloc(const char *mode, const char *path, struct arena_scope *eternal,
    struct arena *scratch)
{
	static const struct config_callbacks *(*callbacks[])(void) = {
		[ROBSD]		= config_robsd_callbacks,
		[ROBSD_CROSS]	= config_robsd_cross_callbacks,
		[ROBSD_PORTS]	= config_robsd_ports_callbacks,
		[ROBSD_REGRESS]	= config_robsd_regress_callbacks,
		[CANVAS]	= config_canvas_callbacks,
	};
	struct config *cf;
	enum robsd_mode m;

	if (robsd_mode_parse(mode, &m)) {
		warnx("unknown mode '%s'", mode);
		return NULL;
	}

	cf = arena_calloc(eternal, 1, sizeof(*cf));
	cf->eternal = eternal;
	cf->scratch = scratch;
	cf->path = path;
	cf->mode = m;
	cf->callbacks = callbacks[cf->mode]();
	if (VECTOR_INIT(cf->grammar))
		err(1, NULL);
	if (VECTOR_INIT(cf->variables))
		err(1, NULL);

	if (cf->callbacks->init(cf)) {
		config_free(cf);
		return NULL;
	}

	return cf;
}

void
config_free(struct config *cf)
{
	if (cf == NULL)
		return;

	cf->callbacks->free(cf);

	VECTOR_FREE(cf->grammar);

	while (!VECTOR_EMPTY(cf->variables)) {
		struct variable *va;

		va = VECTOR_POP(cf->variables);
		variable_value_clear(&va->va_val);
	}
	VECTOR_FREE(cf->variables);

	lexer_free(cf->lx);
}

int
config_parse(struct config *cf)
{
	struct config_lexer_context ctx = {
		.cf	= cf,
	};
	int error;

	arena_scope(cf->scratch, s);

	ctx.bf = arena_buffer_alloc(&s, 1 << 10);
	cf->lx = lexer_alloc(&(struct lexer_arg){
	    .path = cf->path,
	    .callbacks = {
		.read		= config_lexer_read,
		.serialize	= token_serialize,
		.arg		= &ctx,
	    },
	});
	if (cf->lx == NULL) {
		error = 1;
		goto out;
	}
	error = config_parse1(cf);
	if (error)
		goto out;

	cf->callbacks->after_parse(cf);

out:
	return error;
}

int
config_append_var(struct config *cf, const char *str)
{
	char *name, *val;
	size_t namelen;

	arena_scope(cf->scratch, s);

	val = strchr(str, '=');
	if (val == NULL) {
		warnx("missing variable separator in '%s'", str);
		return 1;
	}
	namelen = (size_t)(val - str);
	name = arena_strndup(&s, str, namelen);
	if (config_find_grammar_for_keyword(cf, name) != NULL) {
		warnx("variable '%s' cannot be defined", name);
		return 1;
	}
	val++;	/* consume '=' */
	config_append_string(cf, name, val);
	return 0;
}

static struct variable *
config_append_string(struct config *cf, const char *name, const char *str)
{
	struct variable_value val;

	variable_value_init(&val, STRING);
	val.str = arena_strdup(cf->eternal, str);
	return config_append(cf, name, &val);
}

struct variable *
config_find_or_create_list(struct config *cf, const char *name)
{
	if (!config_present(cf, name)) {
		struct variable_value val;

		variable_value_init(&val, LIST);
		config_append(cf, name, &val);
	}
	return config_find(cf, name);
}

struct variable *
config_find(struct config *cf, const char *name)
{
	static struct variable vadef;
	const struct grammar *gr;
	size_t i, namelen;

	namelen = strlen(name);
	for (i = 0; i < VECTOR_LENGTH(cf->variables); i++) {
		struct variable *va = &cf->variables[i];

		if (va->va_namelen == namelen &&
		    strncmp(va->va_name, name, namelen) == 0)
			return va;
	}

	/* Look for default value. */
	gr = config_find_grammar_for_interpolation(cf, name);
	if (gr == NULL)
		return NULL;
	if (gr->gr_flags & REQ)
		return NULL;
	if (gr->gr_flags & FUN)
		return gr->gr_default.fun(cf, name);

	memset(&vadef, 0, sizeof(vadef));
	vadef.va_val.type = gr->gr_type;
	switch (vadef.va_val.type) {
	case INVALID:
		__builtin_trap();
		/* UNREACHABLE */

	case INTEGER:
		vadef.va_val.integer = gr->gr_default.i32;
		break;

	case STRING:
	case DIRECTORY: {
		const char *str = gr->gr_default.ptr;

		vadef.va_val.str = (str == NULL ? "" : str);
		break;
	}

	case LIST:
		ARENA_VECTOR_INIT(cf->eternal, vadef.va_val.list, 0);
		break;
	}

	return &vadef;
}

const struct variable_value *
config_get_value(struct config *cf, const char *name)
{
	const struct variable *va;

	va = config_find(cf, name);
	if (va == NULL)
		return NULL;
	return &va->va_val;
}

int
config_interpolate_file(struct config *cf, const char *path)
{
	const char *str;

	str = interpolate_file(path, &(struct interpolate_arg){
	    .lookup	= config_interpolate_lookup,
	    .arg	= cf,
	    .eternal	= cf->eternal,
	    .scratch	= cf->scratch,
	});
	if (str == NULL)
		return 1;
	printf("%s", str);
	return 0;
}

const char *
config_interpolate_str(struct config *cf, const char *str)
{
	return interpolate_str(str, &(struct interpolate_arg){
	    .lookup	= config_interpolate_lookup,
	    .arg	= cf,
	    .eternal	= cf->eternal,
	    .scratch	= cf->scratch,
	});
}

/*
 * Returns non-zero if the given variable must be interpolated early.
 */
static int
is_early_variable(const struct config *cf, const char *name)
{
	const struct grammar *gr;

	gr = config_find_grammar_for_interpolation(cf, name);
	return gr != NULL && (gr->gr_flags & EARLY);
}

const char *
config_interpolate_lookup(const char *name, struct arena_scope *s, void *arg)
{
	struct config *cf = (struct config *)arg;
	struct buffer *bf;
	const struct variable *va;

	if (cf->interpolate.early && !is_early_variable(cf, name))
		return NULL;

	va = config_find(cf, name);
	if (va == NULL || !is_variable_value_valid(&va->va_val))
		return NULL;

	bf = arena_buffer_alloc(s, 128);
	switch (va->va_val.type) {
	case INVALID:
		__builtin_trap();
		/* UNREACHABLE */

	case INTEGER:
		buffer_printf(bf, "%d", va->va_val.integer);
		break;

	case STRING:
	case DIRECTORY:
		buffer_printf(bf, "%s", va->va_val.str);
		break;

	case LIST: {
		size_t i;

		for (i = 0; i < VECTOR_LENGTH(va->va_val.list); i++) {
			if (i > 0)
				buffer_printf(bf, " ");
			buffer_printf(bf, "%s", va->va_val.list[i]);
		}
		break;
	}
	}
	return buffer_str(bf);
}

const char *
config_interpolate_early(struct config *cf, const char *template)
{
	const char *str;

	cf->interpolate.early = 1;
	str = interpolate_str(template, &(struct interpolate_arg){
	    .lookup	= config_interpolate_lookup,
	    .arg	= cf,
	    .eternal	= cf->eternal,
	    .scratch	= cf->scratch,
	    .flags	= INTERPOLATE_IGNORE_LOOKUP_ERRORS,
	});
	cf->interpolate.early = 0;
	return str;
}

enum robsd_mode
config_get_mode(const struct config *cf)
{
	return cf->mode;
}

void
config_copy_grammar(struct config *cf, const struct grammar *grammar,
    unsigned int len)
{
	size_t common_grammar_len = sizeof(common_grammar) /
	    sizeof(common_grammar[0]);
	unsigned int i;

	if (VECTOR_RESERVE(cf->grammar, len + common_grammar_len))
		err(1, NULL);

	for (i = 0; i < len; i++) {
		const struct grammar **dst;

		dst = VECTOR_ALLOC(cf->grammar);
		if (dst == NULL)
			err(1, NULL);
		*dst = &grammar[i];
	}

	for (i = 0; i < common_grammar_len; i++) {
		const struct grammar **dst;

		dst = VECTOR_ALLOC(cf->grammar);
		if (dst == NULL)
			err(1, NULL);
		*dst = &common_grammar[i];
	}
}

struct config_step *
config_steps_add_script(struct config_step *steps, const char *script,
    const char *step_name)
{
	struct config_step *dst;
	struct variable_value *val;

	dst = VECTOR_CALLOC(steps);
	if (dst == NULL)
		err(1, NULL);
	dst->name = step_name;

	val = &dst->command.val;
	variable_value_init(val, LIST);
	variable_value_append(val, "sh");
	variable_value_append(val, "-eu");
	variable_value_append(val, "${trace}");
	variable_value_append(val, script);
	variable_value_append(val, step_name);

	return dst;
}

void
config_steps_free(void *arg)
{
	VECTOR(struct config_step) steps = arg;
	size_t i;

	for (i = 0; i < VECTOR_LENGTH(steps); i++)
		variable_value_clear(&steps[i].command.val);
}

struct config_step *
config_default_get_steps(struct config *cf, struct arena_scope *s)
{
	VECTOR(struct config_step) steps;
	size_t i;

	ARENA_VECTOR_INIT(s, steps, cf->steps.len);
	arena_cleanup(s, config_steps_free, steps);

	for (i = 0; i < cf->steps.len; i++) {
		const struct config_step *cs = &cf->steps.ptr[i];

		config_steps_add_script(steps, cs->command.path, cs->name);
	}

	return steps;
}

const struct config_step *
config_get_steps(struct config *cf, unsigned int flags, struct arena_scope *s)
{
	VECTOR(struct config_step) steps;
	size_t i;
	int error = 0;

	cf->interpolate.trace = (flags & CONFIG_STEPS_TRACE_COMMAND) ? 1 : 0;

	steps = cf->callbacks->get_steps(cf, s);

	for (i = 0; i < VECTOR_LENGTH(steps); i++) {
		struct variable_value *val = &steps[i].command.val;
		struct variable_value newval;
		size_t j;

		/* Interpolate all command arguments. */
		variable_value_init(&newval, LIST);
		for (j = 0; j < VECTOR_LENGTH(val->list); j++) {
			const char *arg;

			arg = config_interpolate_str(cf, val->list[j]);
			if (arg == NULL) {
				error = 1;
				goto out;
			}
			if (arg[0] == '\0')
				continue;
			variable_value_append(&newval, arg);
		}
		/* Append NULL sentinel required by execvp(3). */
		variable_value_append(&newval, NULL);

		variable_value_clear(&steps[i].command.val);
		steps[i].command.val = newval;
	}

out:
	cf->interpolate.trace = 0;
	if (error)
		return NULL;
	return steps;
}

static struct token *
config_lexer_read(struct lexer *lx, void *arg)
{
	struct config_lexer_context *ctx = (struct config_lexer_context *)arg;
	struct lexer_state s;
	struct buffer *bf = ctx->bf;
	struct token *tk;
	char ch;

again:
	do {
		if (lexer_getc(lx, &ch))
			return NULL;
	} while (isspace((unsigned char)ch));

	s = lexer_get_state(lx);

	if (ch == 0)
		return lexer_emit(lx, &s, LEXER_EOF);

	if (ch == '#') {
		for (;;) {
			if (ch == '\n' || ch == 0)
				break;
			if (lexer_getc(lx, &ch))
				return NULL;
		}
		goto again;
	}

	buffer_reset(bf);

	if (islower((unsigned char)ch)) {
		const char *buf;

		while (islower((unsigned char)ch) ||
		    isdigit((unsigned char)ch) || ch == '-') {
			buffer_putc(bf, ch);
			if (lexer_getc(lx, &ch))
				return NULL;
		}
		lexer_ungetc(lx, ch);
		buffer_putc(bf, '\0');

		buf = buffer_get_ptr(bf);
		if (strcmp("command", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_COMMAND);
		if (strcmp("env", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_ENV);
		if (strcmp("h", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_HOURS);
		if (strcmp("m", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_MINUTES);
		if (strcmp("no-parallel", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_NO_PARALLEL);
		if (strcmp("obj", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_OBJ);
		if (strcmp("packages", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_PACKAGES);
		/*
		 * Limited to canvas, necessary to avoid conflict with
		 * robsd-regress parallel keyword.
		 */
		if (config_get_mode(ctx->cf) == CANVAS &&
		    strcmp("parallel", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_PARALLEL);
		if (strcmp("quiet", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_QUIET);
		if (strcmp("root", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_ROOT);
		if (strcmp("targets", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_TARGETS);
		if (strcmp("s", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_SECONDS);

		if (strcmp("yes", buf) == 0) {
			tk = lexer_emit(lx, &s, TOKEN_BOOLEAN);
			tk->tk_int = 1;
			return tk;
		}
		if (strcmp("no", buf) == 0) {
			tk = lexer_emit(lx, &s, TOKEN_BOOLEAN);
			tk->tk_int = 0;
			return tk;
		}

		tk = lexer_emit(lx, &s, TOKEN_KEYWORD);
		tk->tk_str = estrdup(buf);
		return tk;
	}

	if (isdigit((unsigned char)ch)) {
		int error = 0;
		int val = 0;

		while (isdigit((unsigned char)ch)) {
			int x = ch - '0';

			if (KS_i32_mul_overflow(val, 10, &val) ||
			    KS_i32_add_overflow(val, x, &val))
				error = 1;
			if (lexer_getc(lx, &ch))
				return NULL;
		}
		lexer_ungetc(lx, ch);
		if (error)
			lexer_warnx(lx, s.lno, "integer too big");

		tk = lexer_emit(lx, &s, TOKEN_INTEGER);
		tk->tk_int = val;
		return tk;
	}

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
		if (buffer_get_len(bf) == 0)
			lexer_warnx(lx, s.lno, "empty string");
		buffer_putc(bf, '\0');

		tk = lexer_emit(lx, &s, TOKEN_STRING);
		tk->tk_str = estrdup(buffer_get_ptr(bf));
		return tk;
	}

	if (ch == '{')
		return lexer_emit(lx, &s, TOKEN_LBRACE);
	if (ch == '}')
		return lexer_emit(lx, &s, TOKEN_RBRACE);

	return lexer_emit(lx, &s, TOKEN_UNKNOWN);
}

static const char *
token_serialize(const struct token *tk)
{
	enum token_type type = (enum token_type)tk->tk_type;

	switch (type) {
	case TOKEN_UNKNOWN:
		break;
	case TOKEN_LBRACE:
		return "LBRACE";
	case TOKEN_RBRACE:
		return "RBRACE";
	case TOKEN_KEYWORD:
		return "KEYWORD";
	case TOKEN_COMMAND:
		return "COMMAND";
	case TOKEN_ENV:
		return "ENV";
	case TOKEN_NO_PARALLEL:
		return "NO-PARALLEL";
	case TOKEN_OBJ:
		return "OBJ";
	case TOKEN_PACKAGES:
		return "PACKAGES";
	case TOKEN_PARALLEL:
		return "PARALLEL";
	case TOKEN_QUIET:
		return "QUIET";
	case TOKEN_ROOT:
		return "ROOT";
	case TOKEN_TARGETS:
		return "TARGETS";
	case TOKEN_HOURS:
		return "HOURS";
	case TOKEN_MINUTES:
		return "MINUTES";
	case TOKEN_SECONDS:
		return "SECONDS";
	case TOKEN_BOOLEAN:
		return "BOOLEAN";
	case TOKEN_INTEGER:
		return "INTEGER";
	case TOKEN_STRING:
		return "STRING";
	}
	return "UNKNOWN";
}

static const struct grammar *
config_find_grammar_for_keyword(const struct config *cf, const char *needle)
{
	size_t i, n;

	n = VECTOR_LENGTH(cf->grammar);
	for (i = 0; i < n; i++) {
		const struct grammar *gr = cf->grammar[i];

		if (gr->gr_fn != NULL && strcmp(gr->gr_kw, needle) == 0)
			return gr;
	}
	return NULL;
}

static const struct grammar *
config_find_grammar_for_interpolation(const struct config *cf, const char *name)
{
	size_t i, n;

	n = VECTOR_LENGTH(cf->grammar);
	for (i = 0; i < n; i++) {
		const struct grammar *gr = cf->grammar[i];

		if (grammar_equals(gr, name))
			return gr;
	}
	return NULL;
}

static int
grammar_equals(const struct grammar *gr, const char *needle)
{
	size_t kwlen, needlelen;

	kwlen = strlen(gr->gr_kw);
	needlelen = strlen(needle);
	if (kwlen == needlelen && strncmp(gr->gr_kw, needle, needlelen) == 0)
		return 1;
	if (gr->gr_flags & PAT)
		return fnmatch(gr->gr_kw, needle, 0) == 0;
	return 0;
}

static int
config_parse1(struct config *cf)
{
	struct token *tk;
	int error = 0;

	for (;;) {
		if (lexer_peek(cf->lx, LEXER_EOF))
			break;
		if (!lexer_expect(cf->lx, TOKEN_KEYWORD, &tk)) {
			error = 1;
			break;
		}

		switch (config_parse_keyword(cf, tk)) {
		case CONFIG_ERROR:
			error = 1;
			break;
		case CONFIG_FATAL:
			error = 1;
			goto out;
		}
	}

out:
	if (lexer_get_error(cf->lx))
		return 1;
	if (config_validate(cf))
		return 1;
	return error;
}

static int
config_parse_keyword(struct config *cf, struct token *tk)
{
	const struct grammar *gr;
	struct variable_value val;
	int error = 0;
	int rv;

	gr = config_find_grammar_for_keyword(cf, tk->tk_str);
	if (gr == NULL) {
		lexer_warnx(cf->lx, tk->tk_lno, "unknown keyword '%s'",
		    tk->tk_str);
		return CONFIG_FATAL;
	}

	if ((gr->gr_flags & REP) == 0 && config_present(cf, tk->tk_str)) {
		lexer_warnx(cf->lx, tk->tk_lno,
		    "variable '%s' already defined", tk->tk_str);
		error = 1;
	}
	rv = gr->gr_fn(cf, &val);
	if (rv == CONFIG_APPEND) {
		config_append(cf, tk->tk_str, &val);
	} else if (rv == CONFIG_NOP) {
		/* Configuration variable already inserted. */
	} else {
		error = 1;
	}

	return error;
}

static int
config_validate(const struct config *cf)
{
	size_t i, n;
	int error = 0;

	n = VECTOR_LENGTH(cf->grammar);
	for (i = 0; i < n; i++) {
		const struct grammar *gr = cf->grammar[i];
		const char *str = gr->gr_kw;

		if ((gr->gr_flags & REQ) && !config_present(cf, str)) {
			log_warnx(cf->path, 0,
			    "mandatory variable '%s' missing", str);
			error = 1;
		}
	}

	return error;
}

int
config_parse_boolean(struct config *cf, struct variable_value *val)
{
	struct token *tk;

	if (!lexer_expect(cf->lx, TOKEN_BOOLEAN, &tk))
		return 1;
	variable_value_init(val, INTEGER);
	val->integer = tk->tk_int;
	return 0;
}

int
config_parse_string(struct config *cf, struct variable_value *val)
{
	struct token *tk;

	if (!lexer_expect(cf->lx, TOKEN_STRING, &tk))
		return 1;
	variable_value_init(val, STRING);
	val->str = tk->tk_str;
	return 0;
}

int
config_parse_integer(struct config *cf, struct variable_value *val)
{
	struct token *tk;

	if (!lexer_expect(cf->lx, TOKEN_INTEGER, &tk))
		return 1;
	variable_value_init(val, INTEGER);
	val->integer = tk->tk_int;
	return 0;
}

int
config_parse_glob(struct config *cf, struct variable_value *val)
{
	glob_t g;
	struct token *tk;
	size_t i;
	int error;

	if (!lexer_expect(cf->lx, TOKEN_STRING, &tk))
		return 1;

	variable_value_init(val, LIST);

	error = glob(tk->tk_str, 0, NULL, &g);
	if (error) {
		if (error == GLOB_NOMATCH)
			return 0;

		lexer_warn(cf->lx, tk->tk_lno, "glob: %d", error);
		return error;
	}

	for (i = 0; i < g.gl_pathc; i++) {
		char **dst;

		dst = VECTOR_ALLOC(val->list);
		if (dst == NULL)
			err(1, NULL);
		*dst = arena_strdup(cf->eternal, g.gl_pathv[i]);
	}

	globfree(&g);
	return 0;
}

int
config_parse_list(struct config *cf, struct variable_value *val)
{
	struct token *tk;

	if (!lexer_expect(cf->lx, TOKEN_LBRACE, &tk))
		return 1;
	variable_value_init(val, LIST);
	for (;;) {
		char **dst;

		if (lexer_peek(cf->lx, TOKEN_RBRACE))
			break;
		if (!lexer_expect(cf->lx, TOKEN_STRING, &tk))
			goto err;
		dst = VECTOR_ALLOC(val->list);
		if (dst == NULL)
			err(1, NULL);
		*dst = arena_strdup(cf->eternal, tk->tk_str);
	}
	if (!lexer_expect(cf->lx, TOKEN_RBRACE, &tk))
		goto err;

	return 0;

err:
	variable_value_clear(val);
	return 1;
}

int
config_parse_user(struct config *cf, struct variable_value *val)
{
	struct token *tk;
	const char *user;

	if (!lexer_expect(cf->lx, TOKEN_STRING, &tk))
		return 1;
	variable_value_init(val, STRING);
	user = val->str = tk->tk_str;
	if (getpwnam(user) == NULL) {
		lexer_warnx(cf->lx, tk->tk_lno, "user '%s' not found",
		    user);
		return 1;
	}
	return 0;
}

int
config_parse_directory(struct config *cf, struct variable_value *val)
{
	struct stat st;
	struct token *tk;
	const char *dir, *path;
	int error = 0;

	if (!lexer_expect(cf->lx, TOKEN_STRING, &tk))
		return 1;
	variable_value_init(val, STRING);
	dir = val->str = tk->tk_str;
	/* Empty string error already reported by the lexer. */
	if (dir[0] == '\0')
		return 1;

	path = interpolate_str(dir, &(struct interpolate_arg){
	    .lookup	= config_interpolate_lookup,
	    .arg	= cf,
	    .eternal	= cf->eternal,
	    .scratch	= cf->scratch,
	    .lno	= tk->tk_lno,
	});
	if (path == NULL) {
		error = 1;
	} else if (stat(path, &st) == -1) {
		lexer_warn(cf->lx, tk->tk_lno, "%s", path);
		error = 1;
	} else if (!S_ISDIR(st.st_mode)) {
		lexer_warnx(cf->lx, tk->tk_lno, "%s: is not a directory",
		    path);
		error = 1;
	}
	return error;
}

static struct variable *
config_default_build_dir(struct config *cf, const char *name)
{
	struct buffer *bf = NULL;
	struct variable *va = NULL;
	const char *path;
	char *nl;
	int fd = -1;

	path = interpolate_str("${robsddir}/.running",
	    &(struct interpolate_arg){
		.lookup		= config_interpolate_lookup,
		.arg		= cf,
		.eternal	= cf->eternal,
		.scratch	= cf->scratch,
	});
	if (path == NULL)
		return NULL;

	arena_scope(cf->scratch, s);

	/*
	 * The lock file is only expected to be present while robsd is running.
	 * Therefore do not treat failures as fatal.
	 */
	fd = open(path, O_RDONLY | O_CLOEXEC);
	if (fd == -1)
		goto out;
	bf = arena_buffer_read_fd(&s, fd);
	if (bf == NULL) {
		warn("%s", path);
		goto out;
	}
	buffer_putc(bf, '\0');
	nl = strchr(buffer_get_ptr(bf), '\n');
	if (nl == NULL) {
		warnx("%s: line not found", path);
		goto out;
	}
	*nl = '\0';
	va = config_append_string(cf, name, buffer_get_ptr(bf));

out:
	if (fd != -1)
		close(fd);
	return va;
}

static struct variable *
config_default_exec_dir(struct config *cf, const char *name)
{
	const char *execdir;

	execdir = getenv("EXECDIR");
	if (execdir == NULL || execdir[0] == '\0')
		execdir = "/usr/local/libexec/robsd";
	return config_append_string(cf, name, execdir);
}

static struct variable *
config_default_inet4(struct config *cf, const char *name)
{
	struct variable_value val;
	const char *addr;

	addr = if_group_addr("egress", 4, cf->eternal);
	if (addr == NULL)
		addr = "";
	variable_value_init(&val, STRING);
	val.str = addr;
	return config_append(cf, name, &val);
}

static struct variable *
config_default_inet6(struct config *cf, const char *name)
{
	struct variable_value val;
	const char *addr;

	addr = if_group_addr("egress", 6, cf->eternal);
	if (addr == NULL)
		addr = "";
	variable_value_init(&val, STRING);
	val.str = addr;
	return config_append(cf, name, &val);
}

static struct variable *
config_default_ncpu(struct config *cf, const char *name)
{
	struct variable_value val;
	long ncpu;

	ncpu = sysconf(_SC_NPROCESSORS_ONLN);
	if (ncpu == -1)
		ncpu = 1;
	variable_value_init(&val, INTEGER);
	val.integer = ncpu;
	return config_append(cf, name, &val);
}

static struct variable *
config_default_trace(struct config *cf, const char *name)
{
	struct variable_value val;

	variable_value_init(&val, STRING);
	val.str = cf->interpolate.trace ? "-x" : "";
	return config_append(cf, name, &val);
}

struct variable *
config_append(struct config *cf, const char *name,
    const struct variable_value *val)
{
	struct variable *va;

	va = VECTOR_CALLOC(cf->variables);
	if (va == NULL)
		err(1, NULL);
	va->va_name = arena_strdup(cf->eternal, name);
	va->va_namelen = strlen(name);
	va->va_val = *val;
	return va;
}

int
config_present(const struct config *cf, const char *name)
{
	size_t i;

	for (i = 0; i < VECTOR_LENGTH(cf->variables); i++) {
		const struct variable *va = &cf->variables[i];

		if (strcmp(va->va_name, name) == 0)
			return 1;
	}
	return 0;
}
