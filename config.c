#include "config.h"

#include <sys/param.h>	/* MACHINE, MACHINE_ARCH */
#include <sys/stat.h>
#include <sys/queue.h>

#include <assert.h>
#include <ctype.h>
#include <err.h>
#include <fcntl.h>
#include <glob.h>
#include <limits.h>
#include <pwd.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "buffer.h"
#include "extern.h"
#include "lexer.h"
#include "token.h"
#include "util.h"

/*
 * token -----------------------------------------------------------------------
 */

enum token_type {
	/* sentinels */
	TOKEN_UNKNOWN,

	/* literals */
	TOKEN_LBRACE,
	TOKEN_RBRACE,

	/* keywords */
	TOKEN_KEYWORD,
	TOKEN_ENV,
	TOKEN_OBJ,
	TOKEN_PACKAGES,
	TOKEN_QUIET,
	TOKEN_ROOT,
	TOKEN_TARGET,

	/* types */
	TOKEN_BOOLEAN,
	TOKEN_INTEGER,
	TOKEN_STRING,
};

static const char	*tokenstr(int);

/*
 * lexer -----------------------------------------------------------------------
 */

static int	lexer_read(struct lexer *, struct token *, void *);

/*
 * variable --------------------------------------------------------------------
 */

union variable_value {
	const void		*ptr;
	char			*str;
	struct string_list	*list;
	int			 integer;
};

struct variable {
	char			*va_name;
	size_t			 va_namelen;
	union variable_value	 va_val;

	int			 va_lno;
	unsigned int		 va_flags;
#define VARIABLE_FLAG_DIRTY	0x00000001u

	enum variable_type {
		INTEGER,
		STRING,
		DIRECTORY,
		LIST,
	} va_type;

	TAILQ_ENTRY(variable)	 va_entry;
};

TAILQ_HEAD(variable_list, variable);

/*
 * grammar ---------------------------------------------------------------------
 */

struct grammar {
	const char		*gr_kw;
	enum variable_type	 gr_type;
	int			 (*gr_fn)(struct config *,
	    union variable_value *);
	unsigned int		 gr_flags;
#define REQ	0x00000001u	/* required */
#define REP	0x00000002u	/* may be repeated */

	const void		*gr_default;
};

static const struct grammar	*grammar_find(const struct grammar *,
    const char *);

/*
 * config ----------------------------------------------------------------------
 */

struct config {
	struct lexer		*cf_lx;
	struct variable_list	 cf_variables;
	const struct grammar	*cf_grammar;
	const char		*cf_path;
	enum {
		CONFIG_ROBSD,
		CONFIG_ROBSD_CROSS,
		CONFIG_ROBSD_PORTS,
		CONFIG_ROBSD_REGRESS,
	} cf_mode;
};

static int	config_mode(const char *, int *);

static int	config_exec(struct config *);
static int	config_exec1(struct config *, struct token *);
static int	config_validate(const struct config *);
static int	config_parse_boolean(struct config *, union variable_value *);
static int	config_parse_string(struct config *, union variable_value *);
static int	config_parse_integer(struct config *, union variable_value *);
static int	config_parse_glob(struct config *, union variable_value *);
static int	config_parse_list(struct config *, union variable_value *);
static int	config_parse_user(struct config *, union variable_value *);
static int	config_parse_regress(struct config *, union variable_value *);
static int	config_parse_directory(struct config *, union variable_value *);

static int			 config_append_defaults(struct config *);
static struct variable		*config_append(struct config *,
    enum variable_type, const char *, const union variable_value *, int,
    unsigned int);
static const struct variable	*config_findn(const struct config *,
    const char *, size_t);
static int			 config_present(const struct config *,
    const char *);

static int	regressname(char *, size_t, const char *, const char *);

static const void *novalue;

static const struct grammar robsd[] = {
	{ "robsddir",		DIRECTORY,	config_parse_directory,	REQ,	NULL },
	{ "builduser",		STRING,		config_parse_user,	0,	"build" },
	{ "destdir",		DIRECTORY,	config_parse_directory,	REQ,	NULL },
	{ "execdir",		DIRECTORY,	config_parse_directory,	0,	"/usr/local/libexec/robsd" },
	{ "hook",		LIST,		config_parse_list,	0,	NULL },
	{ "keep",		INTEGER,	config_parse_integer,	0,	NULL },
	{ "kernel",		STRING,		config_parse_string,	0,	"GENERIC.MP" },
	{ "reboot",		INTEGER,	config_parse_boolean,	0,	NULL },
	{ "skip",		LIST,		config_parse_list,	0,	NULL },
	{ "bsd-diff",		LIST,		config_parse_glob,	0,	NULL },
	{ "bsd-objdir",		DIRECTORY,	config_parse_directory,	0,	"/usr/obj" },
	{ "bsd-srcdir",		DIRECTORY,	config_parse_directory,	0,	"/usr/src" },
	{ "cvs-root",		STRING,		config_parse_string,	0,	NULL },
	{ "cvs-user",		STRING,		config_parse_user,	0,	NULL },
	{ "distrib-host",	STRING,		config_parse_string,	0,	NULL },
	{ "distrib-path",	STRING,		config_parse_string,	0,	NULL },
	{ "distrib-signify",	STRING,		config_parse_string,	0,	NULL },
	{ "distrib-user",	STRING,		config_parse_user,	0,	NULL },
	{ "x11-diff",		LIST,		config_parse_glob,	0,	NULL },
	{ "x11-objdir",		DIRECTORY,	config_parse_directory,	0,	"/usr/xobj" },
	{ "x11-srcdir",		DIRECTORY,	config_parse_directory,	0,	"/usr/xenocara" },
	{ NULL,			0,		NULL,			0,	NULL },
};

static const struct grammar robsd_cross[] = {
	{ "robsddir",	DIRECTORY,	config_parse_directory,	REQ,	NULL },
	{ "builduser",	STRING,		config_parse_user,	0,	"build" },
	{ "crossdir",	STRING,		config_parse_string,	REQ,	NULL },
	{ "execdir",	DIRECTORY,	config_parse_directory,	0,	"/usr/local/libexec/robsd" },
	{ "keep",	INTEGER,	config_parse_integer,	0,	NULL },
	{ "skip",	LIST,		config_parse_list,	0,	NULL },
	{ "bsd-srcdir",	DIRECTORY,	config_parse_directory,	0,	"/usr/src" },
	{ NULL,		0,		NULL,			0,	NULL },
};

static const struct grammar robsd_ports[] = {
	{ "robsddir",		DIRECTORY,	config_parse_directory,	REQ,	NULL },
	{ "chroot",		STRING,		config_parse_string,	REQ,	NULL },
	{ "execdir",		DIRECTORY,	config_parse_directory,	0,	"/usr/local/libexec/robsd" },
	{ "hook",		LIST,		config_parse_list,	0,	NULL },
	{ "keep",		INTEGER,	config_parse_integer,	0,	NULL },
	{ "skip",		LIST,		config_parse_list,	0,	NULL },
	{ "cvs-root",		STRING,		config_parse_string,	0,	NULL },
	{ "cvs-user",		STRING,		config_parse_user,	0,	NULL },
	{ "distrib-host",	STRING,		config_parse_string,	0,	NULL },
	{ "distrib-path",	STRING,		config_parse_string,	0,	NULL },
	{ "distrib-signify",	STRING,		config_parse_string,	0,	NULL },
	{ "distrib-user",	STRING,		config_parse_user,	0,	NULL },
	{ "ports",		LIST,		config_parse_list,	REQ,	NULL },
	{ "ports-diff",		LIST,		config_parse_glob,	0,	NULL },
	{ "ports-dir",		STRING,		config_parse_string,	0,	"/usr/ports" },
	{ "ports-user",		STRING,		config_parse_user,	REQ,	NULL },
	{ NULL,			0,		NULL,			0,	NULL },
};

static const struct grammar robsd_regress[] = {
	{ "robsddir",		DIRECTORY,	config_parse_directory,	REQ,		NULL },
	{ "execdir",		DIRECTORY,	config_parse_directory,	0,		"/usr/local/libexec/robsd" },
	{ "hook",		LIST,		config_parse_list,	0,		NULL },
	{ "keep",		INTEGER,	config_parse_integer,	0,		NULL },
	{ "rdonly",		INTEGER,	config_parse_boolean,	0,		NULL },
	{ "sudo",		STRING,		config_parse_string,	0,		"doas -n" },
	{ "bsd-diff",		LIST,		config_parse_glob,	0,		NULL },
	{ "bsd-srcdir",		DIRECTORY,	config_parse_directory,	0,		"/usr/src" },
	{ "cvs-root",		STRING,		config_parse_string,	0,		NULL },
	{ "cvs-user",		STRING,		config_parse_user,	0,		NULL },
	{ "regress",		LIST,		config_parse_regress,	REQ|REP,	NULL },
	{ "regress-user",	STRING,		config_parse_user,	0,		"build" },
	{ NULL,			0,		NULL,			0,		NULL },
};

struct config *
config_alloc(const char *mode)
{
	struct config *cf;
	int m;

	if (config_mode(mode, &m)) {
		warnx("unknown mode '%s'", mode);
		return NULL;
	}

	cf = calloc(1, sizeof(*cf));
	if (cf == NULL)
		err(1, NULL);
	cf->cf_mode = m;
	TAILQ_INIT(&cf->cf_variables);

	switch (cf->cf_mode) {
	case CONFIG_ROBSD:
		cf->cf_path = "/etc/robsd.conf";
		cf->cf_grammar = robsd;
		break;
	case CONFIG_ROBSD_CROSS:
		cf->cf_path = "/etc/robsd-cross.conf";
		cf->cf_grammar = robsd_cross;
		break;
	case CONFIG_ROBSD_PORTS:
		cf->cf_path = "/etc/robsd-ports.conf";
		cf->cf_grammar = robsd_ports;
		break;
	case CONFIG_ROBSD_REGRESS:
		cf->cf_path = "/etc/robsd-regress.conf";
		cf->cf_grammar = robsd_regress;
		break;
	}

	return cf;
}

void
config_free(struct config *cf)
{
	struct variable *va;

	if (cf == NULL)
		return;

	while ((va = TAILQ_FIRST(&cf->cf_variables)) != NULL) {
		TAILQ_REMOVE(&cf->cf_variables, va, va_entry);
		switch (va->va_type) {
		case INTEGER:
			break;
		case STRING:
		case DIRECTORY:
			if (va->va_flags & VARIABLE_FLAG_DIRTY)
				free(va->va_val.str);
			break;
		case LIST:
			strings_free(va->va_val.list);
			break;
		}
		free(va->va_name);
		free(va);
	}

	lexer_free(cf->cf_lx);
	free(cf);
}

void
config_set_path(struct config *cf, const char *path)
{
	cf->cf_path = path;
}

int
config_parse(struct config *cf)
{
	cf->cf_lx = lexer_alloc(&(struct lexer_arg){
		.path = cf->cf_path,
		.callbacks = {
			.read = lexer_read,
			.serialize = tokenstr,
		},
	});
	if (cf->cf_lx == NULL)
		return 1;
	if (config_exec(cf))
		return 1;
	return 0;
}

int
config_append_var(struct config *cf, const char *str)
{
	char *name, *val;
	int error;

	val = strchr(str, '=');
	if (val == NULL) {
		warnx("missing variable separator in '%s'", str);
		return 1;
	}
	name = strndup(str, val - str);
	if (name == NULL)
		err(1, NULL);
	val++;	/* consume '=' */
	error = config_append_string(cf, name, val);
	if (error)
		warnx("variable '%s' cannot be defined", name);
	free(name);
	return error;
}

int
config_append_string(struct config *cf, const char *name, const char *str)
{
	union variable_value val;

	if (grammar_find(cf->cf_grammar, name))
		return 1;

	val.str = strdup(str);
	if (val.str == NULL)
		err(1, NULL);
	config_append(cf, STRING, name, &val, 0, VARIABLE_FLAG_DIRTY);
	return 0;
}

struct variable *
config_find(struct config *cf, const char *name)
{
	return (struct variable *)config_findn(cf, name, strlen(name));
}

int
config_interpolate(struct config *cf)
{
	FILE *fh = stdin;
	char *buf = NULL;
	size_t bufsiz = 0;
	int error = 0;
	int lno = 0;

	if (config_append_defaults(cf))
		return 1;

	for (;;) {
		char *line;
		ssize_t buflen;

		buflen = getline(&buf, &bufsiz, fh);
		if (buflen == -1) {
			if (feof(fh))
				break;
			warn("getline");
			error = 1;
			break;
		}
		line = config_interpolate_str(cf, buf, "/dev/stdin", ++lno);
		if (line == NULL) {
			error = 1;
			break;
		}
		printf("%s", line);
		free(line);
	}

	free(buf);
	return error;
}

char *
config_interpolate_str(const struct config *cf, const char *str,
    const char *path, int lno)
{
	struct buffer *buf;
	char *bp = NULL;

	buf = buffer_alloc(1024);

	for (;;) {
		const struct variable *va;
		const char *p, *ve, *vs;
		size_t len;

		p = strchr(str, '$');
		if (p == NULL)
			break;
		vs = &p[1];
		if (*vs != '{') {
			log_warnx(path, lno,
			    "invalid substitution, expected '{'");
			goto out;
		}
		vs += 1;
		ve = strchr(vs, '}');
		if (ve == NULL) {
			log_warnx(path, lno,
			    "invalid substitution, expected '}'");
			goto out;
		}
		len = ve - vs;
		if (len == 0) {
			log_warnx(path, lno,
			    "invalid substitution, empty variable name");
			goto out;
		}

		va = config_findn(cf, vs, len);
		if (va == NULL) {
			log_warnx(path, lno,
			    "invalid substitution, unknown variable '%.*s'",
			    (int)len, vs);
			goto out;
		}

		buffer_puts(buf, str, p - str);

		switch (va->va_type) {
		case INTEGER:
			buffer_printf(buf, "%d", va->va_val.integer);
			break;

		case STRING:
		case DIRECTORY: {
			char *vp;

			vp = config_interpolate_str(cf, va->va_val.str,
			    path, lno);
			if (vp == NULL)
				goto out;
			buffer_printf(buf, "%s", vp);
			free(vp);
			break;
		}

		case LIST: {
			const struct string *last, *st;

			last = TAILQ_LAST(va->va_val.list, string_list);
			TAILQ_FOREACH(st, va->va_val.list, st_entry) {
				char *vp;

				vp = config_interpolate_str(cf, st->st_val,
				    path, lno);
				if (vp == NULL)
					goto out;
				buffer_printf(buf, "%s%s", vp,
				    last == st ? "" : " ");
				free(vp);
			}
			break;
		}
		}

		str = &ve[1];
	}
	/* Output any remaining tail. */
	buffer_puts(buf, str, strlen(str));

	buffer_putc(buf, '\0');
	bp = buffer_release(buf);
out:
	buffer_free(buf);
	return bp;
}

const struct string_list *
variable_list(const struct variable *va)
{
	assert(va->va_type == LIST);
	return va->va_val.list;
}

void
token_free(struct token *tk)
{
	if (tk == NULL)
		return;

	switch (tk->tk_type) {
	case TOKEN_KEYWORD:
	case TOKEN_STRING:
		free(tk->tk_str);
		break;
	case TOKEN_UNKNOWN:
	case TOKEN_LBRACE:
	case TOKEN_RBRACE:
	case TOKEN_ENV:
	case TOKEN_OBJ:
	case TOKEN_PACKAGES:
	case TOKEN_QUIET:
	case TOKEN_ROOT:
	case TOKEN_TARGET:
	case TOKEN_BOOLEAN:
	case TOKEN_INTEGER:
		break;
	}
	free(tk);
}

static const char *
tokenstr(int type)
{
	switch ((enum token_type)type) {
	case TOKEN_UNKNOWN:
		break;
	case TOKEN_LBRACE:
		return "LBRACE";
	case TOKEN_RBRACE:
		return "RBRACE";
	case TOKEN_KEYWORD:
		return "KEYWORD";
	case TOKEN_ENV:
		return "ENV";
	case TOKEN_OBJ:
		return "OBJ";
	case TOKEN_PACKAGES:
		return "PACKAGES";
	case TOKEN_QUIET:
		return "QUIET";
	case TOKEN_ROOT:
		return "ROOT";
	case TOKEN_TARGET:
		return "TARGET";
	case TOKEN_BOOLEAN:
		return "BOOLEAN";
	case TOKEN_INTEGER:
		return "INTEGER";
	case TOKEN_STRING:
		return "STRING";
	}
	if (type == LEXER_EOF)
		return "EOF";
	return "UNKNOWN";
}

static int
lexer_read(struct lexer *lx, struct token *tk, void *UNUSED(arg))
{
#define CONSUME(c) do {							\
	if (buflen >= sizeof(buf)) {					\
		lexer_warnx(lx, lexer_get_lno(lx), "token too long");	\
		return 1;						\
	}								\
	buf[buflen++] = (c);						\
} while (0)

	static char buf[512];
	unsigned int buflen = 0;
	char ch;

again:
	do {
		if (lexer_getc(lx, &ch))
			return 1;
	} while (isspace((unsigned char)ch));

	tk->tk_lno = lexer_get_lno(lx);

	if (ch == 0) {
		tk->tk_type = LEXER_EOF;
		return 0;
	}

	if (ch == '#') {
		for (;;) {
			if (ch == '\n' || ch == 0)
				break;
			if (lexer_getc(lx, &ch))
				return 1;
		}
		goto again;
	}

	if (islower((unsigned char)ch)) {
		while (islower((unsigned char)ch) ||
		    isdigit((unsigned char)ch) || ch == '-') {
			CONSUME(ch);
			if (lexer_getc(lx, &ch))
				return 1;
		}
		lexer_ungetc(lx, ch);

		if (strncmp("env", buf, buflen) == 0) {
			tk->tk_type = TOKEN_ENV;
			return 0;
		}
		if (strncmp("obj", buf, buflen) == 0) {
			tk->tk_type = TOKEN_OBJ;
			return 0;
		}
		if (strncmp("packages", buf, buflen) == 0) {
			tk->tk_type = TOKEN_PACKAGES;
			return 0;
		}
		if (strncmp("quiet", buf, buflen) == 0) {
			tk->tk_type = TOKEN_QUIET;
			return 0;
		}
		if (strncmp("root", buf, buflen) == 0) {
			tk->tk_type = TOKEN_ROOT;
			return 0;
		}
		if (strncmp("target", buf, buflen) == 0) {
			tk->tk_type = TOKEN_TARGET;
			return 0;
		}

		if (strncmp("yes", buf, buflen) == 0) {
			tk->tk_type = TOKEN_BOOLEAN;
			tk->tk_int = 1;
			return 0;
		}
		if (strncmp("no", buf, buflen) == 0) {
			tk->tk_type = TOKEN_BOOLEAN;
			tk->tk_int = 0;
			return 0;
		}

		tk->tk_type = TOKEN_KEYWORD;
		tk->tk_str = strndup(buf, buflen);
		if (tk->tk_str == NULL)
			err(1, NULL);
		return 0;
	}

	if (isdigit((unsigned char)ch)) {
		int error = 0;
		int val = 0;

		while (isdigit((unsigned char)ch)) {
			int x;

			x = ch - '0';
			if (val > INT_MAX / 10 || val * 10 > INT_MAX - x) {
				if (!error)
					lexer_warnx(lx, lexer_get_lno(lx),
					    "integer too big");
				error = 1;
			} else {
				val *= 10;
				val += x;
			}
			if (lexer_getc(lx, &ch))
				return 1;
		}
		lexer_ungetc(lx, ch);
		if (error)
			return 1;

		tk->tk_type = TOKEN_INTEGER;
		tk->tk_int = val;
		return 0;
	}

	if (ch == '"') {
		for (;;) {
			if (lexer_getc(lx, &ch))
				return 1;
			if (ch == 0) {
				lexer_warnx(lx, lexer_get_lno(lx),
				    "unterminated string");
				return 1;
			}
			if (ch == '"')
				break;
			CONSUME(ch);
		}
		if (buflen == 0)
			lexer_warnx(lx, lexer_get_lno(lx), "empty string");
		CONSUME('\0');

		tk->tk_type = TOKEN_STRING;
		tk->tk_str = strndup(buf, buflen);
		if (tk->tk_str == NULL)
			err(1, NULL);
		return 0;
	}

	if (ch == '{') {
		tk->tk_type = TOKEN_LBRACE;
		return 0;
	}
	if (ch == '}') {
		tk->tk_type = TOKEN_RBRACE;
		return 0;
	}

	tk->tk_type = TOKEN_UNKNOWN;
	return 0;
}

static const struct grammar *
grammar_find(const struct grammar *grammar, const char *name)
{
	int i;

	for (i = 0; grammar[i].gr_kw != NULL; i++) {
		if (strcmp(grammar[i].gr_kw, name) == 0)
			return &grammar[i];
	}
	return NULL;
}

static int
config_mode(const char *mode, int *res)
{
	if (strcmp(mode, "robsd") == 0)
		*res = CONFIG_ROBSD;
	else if (strcmp(mode, "robsd-cross") == 0)
		*res = CONFIG_ROBSD_CROSS;
	else if (strcmp(mode, "robsd-ports") == 0)
		*res = CONFIG_ROBSD_PORTS;
	else if (strcmp(mode, "robsd-regress") == 0)
		*res = CONFIG_ROBSD_REGRESS;
	else
		return 1;
	return 0;
}

static int
config_exec(struct config *cf)
{
	struct token *tk;
	int error = 0;

	for (;;) {
		if (lexer_peek(cf->cf_lx, LEXER_EOF))
			break;
		if (!lexer_expect(cf->cf_lx, TOKEN_KEYWORD, &tk)) {
			error = 1;
			break;
		}

		switch (config_exec1(cf, tk)) {
		case 1:
			error = 1;
			break;
		case -1:
			error = 1;
			goto out;
		}
	}

out:
	if (lexer_get_error(cf->cf_lx))
		return 1;
	if (config_validate(cf))
		return 1;
	return error;
}

static int
config_exec1(struct config *cf, struct token *tk)
{
	const struct grammar *gr;
	union variable_value val;
	int error = 0;

	gr = grammar_find(cf->cf_grammar, tk->tk_str);
	if (gr == NULL) {
		lexer_warnx(cf->cf_lx, tk->tk_lno, "unknown keyword '%s'",
		    tk->tk_str);
		return -1;
	}

	if ((gr->gr_flags & REP) == 0 && config_present(cf, tk->tk_str)) {
		lexer_warnx(cf->cf_lx, tk->tk_lno,
		    "variable '%s' already defined", tk->tk_str);
		error = 1;
	}
	if (gr->gr_fn(cf, &val) == 0) {
		if (val.ptr != novalue)
			config_append(cf, gr->gr_type, tk->tk_str, &val,
			    tk->tk_lno, 0);
	} else {
		error = 1;
	}

	return error;
}

static int
config_validate(const struct config *cf)
{
	int error = 0;
	int i;

	for (i = 0; cf->cf_grammar[i].gr_kw != NULL; i++) {
		const struct grammar *gr = &cf->cf_grammar[i];
		const char *str = gr->gr_kw;

		if ((gr->gr_flags & REQ) &&
		    !config_present(cf, str)) {
			log_warnx(cf->cf_path, 0,
			    "mandatory variable '%s' missing", str);
			error = 1;
		}
	}

	return error;
}

static int
config_parse_boolean(struct config *cf, union variable_value *val)
{
	struct token *tk;

	if (!lexer_expect(cf->cf_lx, TOKEN_BOOLEAN, &tk))
		return 1;
	val->integer = tk->tk_int;
	return 0;
}

static int
config_parse_string(struct config *cf, union variable_value *val)
{
	struct token *tk;

	if (!lexer_expect(cf->cf_lx, TOKEN_STRING, &tk))
		return 1;
	val->str = tk->tk_str;
	return 0;
}

static int
config_parse_integer(struct config *cf, union variable_value *val)
{
	struct token *tk;

	if (!lexer_expect(cf->cf_lx, TOKEN_INTEGER, &tk))
		return 1;
	val->integer = tk->tk_int;
	return 0;
}

static int
config_parse_glob(struct config *cf, union variable_value *val)
{
	glob_t g;
	struct token *tk;
	struct string_list *strings = NULL;
	size_t i;
	int error;

	if (!lexer_expect(cf->cf_lx, TOKEN_STRING, &tk))
		return 1;
	error = glob(tk->tk_str, GLOB_NOCHECK, NULL, &g);
	if (error) {
		lexer_warn(cf->cf_lx, tk->tk_lno, "glob: %d", error);
		goto out;
	}

	strings = strings_alloc();
	for (i = 0; i < g.gl_matchc; i++)
		strings_append(strings, g.gl_pathv[i]);

out:
	globfree(&g);
	val->list = strings;
	return 0;
}

static int
config_parse_list(struct config *cf, union variable_value *val)
{
	struct string_list *strings = NULL;
	struct token *tk;

	if (!lexer_expect(cf->cf_lx, TOKEN_LBRACE, &tk))
		return 1;
	strings = strings_alloc();
	for (;;) {
		if (lexer_peek(cf->cf_lx, TOKEN_RBRACE))
			break;
		if (!lexer_expect(cf->cf_lx, TOKEN_STRING, &tk))
			goto err;
		strings_append(strings, tk->tk_str);
	}
	if (!lexer_expect(cf->cf_lx, TOKEN_RBRACE, &tk))
		goto err;

	val->list = strings;
	return 0;

err:
	strings_free(strings);
	return 1;
}

static int
config_parse_user(struct config *cf, union variable_value *val)
{
	struct token *tk;
	const char *user;

	if (!lexer_expect(cf->cf_lx, TOKEN_STRING, &tk))
		return 1;
	user = val->str = tk->tk_str;
	if (getpwnam(user) == NULL) {
		lexer_warnx(cf->cf_lx, tk->tk_lno, "user '%s' not found",
		    user);
		return 1;
	}
	return 0;
}

static int
config_parse_regress(struct config *cf, union variable_value *val)
{
	struct lexer *lx = cf->cf_lx;
	struct token *tk;
	struct variable *regress;
	const char *path;

	if (!lexer_expect(lx, TOKEN_STRING, &tk))
		return 1;
	path = tk->tk_str;

	for (;;) {
		char name[128];

		if (lexer_if(lx, TOKEN_ENV, &tk)) {
			union variable_value newval;

			if (config_parse_list(cf, &newval))
				return 1;
			if (regressname(name, sizeof(name), path, "env")) {
				lexer_warnx(lx, tk->tk_lno, "name too long");
				return 1;
			}
			config_append(cf, LIST, name, &newval, tk->tk_lno, 0);
		} else if (lexer_if(lx, TOKEN_OBJ, &tk)) {
			union variable_value newval;
			struct variable *obj;

			if (config_parse_list(cf, &newval))
				return 1;
			obj = config_find(cf, "regress-obj");
			if (obj == NULL) {
				union variable_value def;

				def.list = strings_alloc();
				obj = config_append(cf, LIST, "regress-obj",
				    &def, 0, 0);
			}
			strings_concat(obj->va_val.list, newval.list);
		} else if (lexer_if(lx, TOKEN_PACKAGES, &tk)) {
			union variable_value newval;
			struct variable *packages;

			if (config_parse_list(cf, &newval))
				return 1;
			packages = config_find(cf, "regress-packages");
			if (packages == NULL) {
				union variable_value def;

				def.list = strings_alloc();
				packages = config_append(cf, LIST,
				    "regress-packages", &def, 0, 0);
			}
			strings_concat(packages->va_val.list, newval.list);
		} else if (lexer_if(lx, TOKEN_QUIET, &tk)) {
			union variable_value newval = {.integer = 1};

			if (regressname(name, sizeof(name), path, "quiet")) {
				lexer_warnx(lx, tk->tk_lno, "name too long");
				return 1;
			}
			config_append(cf, INTEGER, name, &newval,
			    tk->tk_lno, 0);
		} else if (lexer_if(lx, TOKEN_ROOT, &tk)) {
			union variable_value newval = {.integer = 1};

			if (regressname(name, sizeof(name), path, "root")) {
				lexer_warnx(lx, tk->tk_lno, "name too long");
				return 1;
			}
			config_append(cf, INTEGER, name, &newval,
			    tk->tk_lno, 0);
		} else if (lexer_if(lx, TOKEN_TARGET, &tk)) {
			union variable_value newval;

			if (config_parse_string(cf, &newval))
				return 1;
			if (regressname(name, sizeof(name), path, "target")) {
				lexer_warnx(lx, tk->tk_lno, "name too long");
				return 1;
			}
			config_append(cf, STRING, name, &newval,
			    tk->tk_lno, 0);
		} else {
			break;
		}
	}

	regress = config_find(cf, "regress");
	if (regress == NULL) {
		union variable_value newval;

		newval.list = strings_alloc();
		regress = config_append(cf, LIST, "regress", &newval, 0, 0);
	}
	strings_append(regress->va_val.list, path);

	val->ptr = novalue;
	return 0;
}

static int
config_parse_directory(struct config *cf, union variable_value *val)
{
	struct stat st;
	struct token *tk;
	const char *dir;
	char *path;
	int error = 0;

	if (!lexer_expect(cf->cf_lx, TOKEN_STRING, &tk))
		return 1;
	dir = val->str = tk->tk_str;
	/* Empty string error already reported by the lexer. */
	if (dir[0] == '\0')
		return 1;

	path = config_interpolate_str(cf, dir, cf->cf_path, tk->tk_lno);
	if (path == NULL) {
		error = 1;
	} else if (stat(path, &st) == -1) {
		lexer_warn(cf->cf_lx, tk->tk_lno, "%s", path);
		error = 1;
	} else if (!S_ISDIR(st.st_mode)) {
		lexer_warnx(cf->cf_lx, tk->tk_lno, "%s: is not a directory",
		    path);
		error = 1;
	}
	free(path);
	return error;
}

/*
 * Append read-only variables accessible during interpolation.
 */
static int
config_append_defaults(struct config *cf)
{
	union variable_value val;

	config_append_string(cf, "arch", MACHINE_ARCH);
	config_append_string(cf, "machine", MACHINE);

	val.str = config_interpolate_str(cf, "${robsddir}/attic",
	    cf->cf_path, 0);
	if (val.str == NULL)
		return 1;
	config_append(cf, STRING, "keep-dir", &val, 0, VARIABLE_FLAG_DIRTY);

	if (cf->cf_mode == CONFIG_ROBSD_REGRESS) {
		val.str = ifgrinet("egress");
		if (val.str == NULL)
			return 1;
		config_append(cf, STRING, "inet", &val, 0, VARIABLE_FLAG_DIRTY);
	}

	return 0;
}

static struct variable *
config_append(struct config *cf, enum variable_type type, const char *name,
    const union variable_value *val, int lno, unsigned int flags)
{
	struct variable *va;

	va = calloc(1, sizeof(*va));
	if (va == NULL)
		err(1, NULL);
	va->va_type = type;
	va->va_lno = lno;
	va->va_flags = flags;
	va->va_name = strdup(name);
	if (va->va_name == NULL)
		err(1, NULL);
	va->va_namelen = strlen(name);
	va->va_val = *val;
	TAILQ_INSERT_TAIL(&cf->cf_variables, va, va_entry);
	return va;
}

static const struct variable *
config_findn(const struct config *cf, const char *name, size_t namelen)
{
	static struct variable vadef;
	const struct variable *va;
	int i;

	TAILQ_FOREACH(va, &cf->cf_variables, va_entry) {
		if (va->va_namelen == namelen &&
		    strncmp(va->va_name, name, namelen) == 0)
			return va;
	}

	/* Look for default value. */
	for (i = 0; cf->cf_grammar[i].gr_kw != NULL; i++) {
		const struct grammar *gr = &cf->cf_grammar[i];
		const void *val;
		size_t kwlen;

		if (gr->gr_flags & REQ)
			continue;

		kwlen = strlen(gr->gr_kw);
		if (kwlen != namelen ||
		    strncmp(gr->gr_kw, name, namelen) != 0)
			continue;

		memset(&vadef, 0, sizeof(vadef));
		vadef.va_type = gr->gr_type;
		val = gr->gr_default;
		switch (vadef.va_type) {
		case INTEGER:
			vadef.va_val.integer = 0;
			break;

		case STRING:
		case DIRECTORY: {
			vadef.va_val.str = (char *)(val == NULL ? "" : val);
			break;
		}

		case LIST: {
			static struct string_list def;

			TAILQ_INIT(&def);
			vadef.va_val.list = &def;
		}
		}
		return &vadef;
	}

	return NULL;
}

static int
config_present(const struct config *cf, const char *name)
{
	const struct variable *va;

	TAILQ_FOREACH(va, &cf->cf_variables, va_entry) {
		if (strcmp(va->va_name, name) == 0)
			return 1;
	}
	return 0;
}

static int
regressname(char *buf, size_t bufsiz, const char *path, const char *suffix)
{
	int n;

	n = snprintf(buf, bufsiz, "regress-%s-%s", path, suffix);
	if (n < 0 || (size_t)n >= bufsiz)
		return 1;
	return 0;
}
