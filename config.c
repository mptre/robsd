#include "config.h"

#include <sys/stat.h>
#include <sys/queue.h>

#include <assert.h>
#include <ctype.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <glob.h>
#include <limits.h>
#include <pwd.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "extern.h"

/*
 * lexer -----------------------------------------------------------------------
 */

struct lexer {
	TAILQ_HEAD(token_list, token)	 lx_tokens;
	struct token			*lx_tk;

	const char			*lx_path;
	FILE				*lx_fh;
	int				 lx_lno;

	int				 lx_err;
};

struct token {
	enum token_type {
		TOKEN_EOF,

		TOKEN_LBRACE,
		TOKEN_RBRACE,

		TOKEN_KEYWORD,
		TOKEN_ENV,
		TOKEN_QUIET,
		TOKEN_ROOT,

		TOKEN_BOOLEAN,
		TOKEN_INTEGER,
		TOKEN_STRING,

		TOKEN_UNKNOWN,
	} tk_type;
	int			tk_lno;

	union {
		char	*tk_str;
		int64_t	 tk_int;
	};

	TAILQ_ENTRY(token)	tk_entry;
};

static int	lexer_init(struct lexer *, const char *);
static void	lexer_free(struct lexer *);
static int	lexer_getc(struct lexer *, char *);
static void	lexer_ungetc(struct lexer *, char);
static int	lexer_read(struct lexer *, struct token *);
static int	lexer_next(struct lexer *, struct token **);
static int	lexer_expect(struct lexer *, enum token_type, struct token **);
static int	lexer_peek(struct lexer *, enum token_type);
static int	lexer_if(struct lexer *, enum token_type, struct token **);

static void	lexer_warn(struct lexer *, int, const char *, ...)
	__attribute__((format(printf, 3, 4)));
static void	lexer_warnx(struct lexer *, int, const char *, ...)
	__attribute__((format(printf, 3, 4)));

static void		 token_free(struct token *);
static const char	*tokenstr(enum token_type);

static int
lexer_init(struct lexer *lx, const char *path)
{
	int error = 0;

	lx->lx_fh = fopen(path, "r");
	if (lx->lx_fh == NULL) {
		warn("open: %s", path);
		return 1;
	}
	lx->lx_path = path;
	lx->lx_lno = 1;
	lx->lx_tk = NULL;
	TAILQ_INIT(&lx->lx_tokens);

	for (;;) {
		struct token *tk;

		tk = calloc(1, sizeof(*tk));
		if (tk == NULL)
			err(1, NULL);
		if (lexer_read(lx, tk)) {
			free(tk);
			error = 1;
			goto out;
		}
		TAILQ_INSERT_TAIL(&lx->lx_tokens, tk, tk_entry);
		if (tk->tk_type == TOKEN_EOF)
			break;
	}

out:
	fclose(lx->lx_fh);
	lx->lx_fh = NULL;
	return error;
}

static void
lexer_free(struct lexer *lx)
{
	struct token *tk;

	if (lx == NULL)
		return;

	while ((tk = TAILQ_FIRST(&lx->lx_tokens)) != NULL) {
		TAILQ_REMOVE(&lx->lx_tokens, tk, tk_entry);
		token_free(tk);
	}

	if (lx->lx_fh != NULL)
		fclose(lx->lx_fh);
}

static int
lexer_getc(struct lexer *lx, char *ch)
{
	int rv;

	rv = fgetc(lx->lx_fh);
	if (rv == EOF) {
		if (ferror(lx->lx_fh)) {
			lexer_warn(lx, lx->lx_lno, "fgetc");
			return 1;
		}
		*ch = 0;
		return 0;
	}
	if (rv == '\n')
		lx->lx_lno++;
	*ch = rv;
	return 0;
}

static void
lexer_ungetc(struct lexer *lx, char ch)
{
	if (ch == '\n' && lx->lx_lno > 1)
		lx->lx_lno--;
	(void)ungetc(ch, lx->lx_fh);
}

static int
lexer_read(struct lexer *lx, struct token *tk)
{
#define CONSUME(c) do {							\
	if (buflen >= sizeof(buf)) {					\
		lexer_warnx(lx, lx->lx_lno, "token too long");		\
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

	tk->tk_lno = lx->lx_lno;

	if (ch == 0) {
		tk->tk_type = TOKEN_EOF;
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
		if (strncmp("quiet", buf, buflen) == 0) {
			tk->tk_type = TOKEN_QUIET;
			return 0;
		}
		if (strncmp("root", buf, buflen) == 0) {
			tk->tk_type = TOKEN_ROOT;
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
					lexer_warnx(lx, lx->lx_lno,
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
				lexer_warnx(lx, lx->lx_lno,
				    "unterminated string");
				return 1;
			}
			if (ch == '"')
				break;
			CONSUME(ch);
		}
		if (buflen == 0)
			lexer_warnx(lx, lx->lx_lno, "empty string");
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

static int
lexer_next(struct lexer *lx, struct token **tk)
{
	if (lx->lx_tk == NULL)
		lx->lx_tk = TAILQ_FIRST(&lx->lx_tokens);
	else
		lx->lx_tk = TAILQ_NEXT(lx->lx_tk, tk_entry);
	if (lx->lx_tk == NULL)
		return 0;
	*tk = lx->lx_tk;
	return 1;
}

static int
lexer_expect(struct lexer *lx, enum token_type exp, struct token **tk)
{
	enum token_type act;

	if (!lexer_next(lx, tk))
		return 0;
	act = (*tk)->tk_type;
	if (exp != act) {
		lexer_warnx(lx, (*tk)->tk_lno, "want %s, got %s", tokenstr(exp),
		    tokenstr(act));
		return 0;
	}
	return 1;
}

static int
lexer_peek(struct lexer *lx, enum token_type type)
{
	struct token *tk;
	int peek;

	if (!lexer_next(lx, &tk))
		return 0;
	peek = tk->tk_type == type;
	lx->lx_tk = TAILQ_PREV(tk, token_list, tk_entry);
	return peek;
}

static int
lexer_if(struct lexer *lx, enum token_type type, struct token **tk)
{
	if (!lexer_next(lx, tk))
		return 0;
	if ((*tk)->tk_type != type) {
		lx->lx_tk = TAILQ_PREV(*tk, token_list, tk_entry);
		return 0;
	}
	return 1;
}

static void
lexer_warn(struct lexer *lx, int lno, const char *fmt, ...)
{
	va_list ap;

	lx->lx_err++;

	va_start(ap, fmt);
	logv(warn, lx->lx_path, lno, fmt, ap);
	va_end(ap);
}

static void
lexer_warnx(struct lexer *lx, int lno, const char *fmt, ...)
{
	va_list ap;

	lx->lx_err++;

	va_start(ap, fmt);
	logv(warnx, lx->lx_path, lno, fmt, ap);
	va_end(ap);
}

static void
token_free(struct token *tk)
{
	if (tk == NULL)
		return;

	switch (tk->tk_type) {
	case TOKEN_KEYWORD:
	case TOKEN_STRING:
		free(tk->tk_str);
		break;
	case TOKEN_EOF:
	case TOKEN_LBRACE:
	case TOKEN_RBRACE:
	case TOKEN_ENV:
	case TOKEN_QUIET:
	case TOKEN_ROOT:
	case TOKEN_BOOLEAN:
	case TOKEN_INTEGER:
	case TOKEN_UNKNOWN:
		break;
	}
	free(tk);
}

static const char *
tokenstr(enum token_type type)
{
	switch (type) {
	case TOKEN_EOF:
		return "EOF";
	case TOKEN_LBRACE:
		return "LBRACE";
	case TOKEN_RBRACE:
		return "RBRACE";
	case TOKEN_KEYWORD:
		return "KEYWORD";
	case TOKEN_ENV:
		return "ENV";
	case TOKEN_QUIET:
		return "QUIET";
	case TOKEN_ROOT:
		return "ROOT";
	case TOKEN_BOOLEAN:
		return "BOOLEAN";
	case TOKEN_INTEGER:
		return "INTEGER";
	case TOKEN_STRING:
		return "STRING";
	case TOKEN_UNKNOWN:
		break;
	}
	return "UNKNOWN";
}

/*
 * variables -------------------------------------------------------------------
 */

struct variable {
	char			*va_name;
	size_t			 va_namelen;
	union {
		void			*va_val;
		char			*va_str;
		struct string_list	*va_list;
		int			 va_int;
	};

	int			 va_lno;

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
	int			 (*gr_fn)(struct config *, struct token *,
	    void **);
	unsigned int		 gr_flags;
#define REQ	0x00000001u
#define REP	0x00000002u

	void			*gr_default;
};

static const struct grammar	*grammar_find(const struct grammar *,
    const char *);

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

/*
 * config ----------------------------------------------------------------------
 */

struct config {
	struct lexer		 cf_lx;
	struct variable_list	 cf_variables;
	const struct grammar	*cf_grammar;
	const char		*cf_path;
	const char		*cf_builddir;
	enum {
		CONFIG_ROBSD,
		CONFIG_ROBSD_CROSS,
		CONFIG_ROBSD_PORTS,
		CONFIG_ROBSD_REGRESS,
		CONFIG_UNKNOWN,
	} cf_mode;
};

static int	config_mode(const char *);

static int	config_exec(struct config *);
static int	config_exec1(struct config *, struct token *);
static int	config_parse_boolean(struct config *, struct token *, void **);
static int	config_parse_string(struct config *, struct token *, void **);
static int	config_parse_integer(struct config *, struct token *, void **);
static int	config_parse_glob(struct config *, struct token *, void **);
static int	config_parse_list(struct config *, struct token *, void **);
static int	config_parse_user(struct config *, struct token *, void **);
static int	config_parse_regress(struct config *, struct token *, void **);

static int			 config_append_defaults(struct config *);
static struct variable		*config_append(struct config *,
    enum variable_type, const char *, void *, int);
static const struct variable	*config_findn(const struct config *,
    const char *, size_t);
static int			 config_present(const struct config *,
    const char *);

static int	config_validate_directory(const struct config *, const char *);

static char	*crosstarget(const char *);
static int	 regressname(char *, size_t, const char *, const char *);

static const struct grammar robsd[] = {
	{ "robsddir",		DIRECTORY,	config_parse_string,	REQ,	NULL },
	{ "builduser",		STRING,		config_parse_user,	0,	"build" },
	{ "destdir",		DIRECTORY,	config_parse_string,	REQ,	NULL },
	{ "execdir",		DIRECTORY,	config_parse_string,	0,	"/usr/local/libexec/robsd" },
	{ "hook",		LIST,		config_parse_list,	0,	NULL },
	{ "keep",		INTEGER,	config_parse_integer,	0,	NULL },
	{ "kernel",		STRING,		config_parse_string,	0,	"GENERIC.MP" },
	{ "reboot",		INTEGER,	config_parse_boolean,	0,	NULL },
	{ "skip",		LIST,		config_parse_list,	0,	NULL },
	{ "bsd-diff",		LIST,		config_parse_glob,	0,	NULL },
	{ "bsd-objdir",		DIRECTORY,	config_parse_string,	0,	"/usr/obj" },
	{ "bsd-srcdir",		DIRECTORY,	config_parse_string,	0,	"/usr/src" },
	{ "cvs-root",		STRING,		config_parse_string,	0,	NULL },
	{ "cvs-user",		STRING,		config_parse_user,	0,	NULL },
	{ "distrib-host",	STRING,		config_parse_string,	0,	NULL },
	{ "distrib-path",	STRING,		config_parse_string,	0,	NULL },
	{ "distrib-signify",	STRING,		config_parse_string,	0,	NULL },
	{ "distrib-user",	STRING,		config_parse_user,	0,	NULL },
	{ "x11-diff",		LIST,		config_parse_glob,	0,	NULL },
	{ "x11-objdir",		DIRECTORY,	config_parse_string,	0,	"/usr/xobj" },
	{ "x11-srcdir",		DIRECTORY,	config_parse_string,	0,	"/usr/xenocara" },
	{ NULL,			0,		NULL,			0,	NULL },
};

static const struct grammar robsd_cross[] = {
	{ "robsddir",	DIRECTORY,	config_parse_string,	REQ,	NULL },
	{ "builduser",	STRING,		config_parse_user,	0,	"build" },
	{ "crossdir",	STRING,		config_parse_string,	REQ,	NULL },
	{ "execdir",	DIRECTORY,	config_parse_string,	0,	"/usr/local/libexec/robsd" },
	{ "keep",	INTEGER,	config_parse_integer,	0,	NULL },
	{ "kernel",	STRING,		config_parse_string,	0,	"GENERIC.MP" },
	{ "skip",	LIST,		config_parse_list,	0,	NULL },
	/* Not used but needed by kernel step. */
	{ "bsd-objdir",	DIRECTORY,	config_parse_string,	0,	"/usr/obj" },
	{ "bsd-srcdir",	DIRECTORY,	config_parse_string,	0,	"/usr/src" },
	{ NULL,		0,		NULL,			0,	NULL },
};

static const struct grammar robsd_ports[] = {
	{ "robsddir",		DIRECTORY,	config_parse_string,	REQ,	NULL },
	{ "chroot",		STRING,		config_parse_string,	REQ,	NULL },
	{ "execdir",		DIRECTORY,	config_parse_string,	0,	"/usr/local/libexec/robsd" },
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
	{ "robsddir",		DIRECTORY,	config_parse_string,	REQ,		NULL },
	{ "execdir",		DIRECTORY,	config_parse_string,	0,		"/usr/local/libexec/robsd" },
	{ "hook",		LIST,		config_parse_list,	0,		NULL },
	{ "keep",		INTEGER,	config_parse_integer,	0,		NULL },
	{ "rdonly",		INTEGER,	config_parse_boolean,	0,		NULL },
	{ "sudo",		STRING,		config_parse_string,	0,		"doas -n" },
	{ "bsd-diff",		LIST,		config_parse_glob,	0,		NULL },
	{ "bsd-srcdir",		DIRECTORY,	config_parse_string,	0,		"/usr/src" },
	{ "cvs-user",		STRING,		config_parse_user,	0,		NULL },
	{ "regress",		LIST,		config_parse_regress,	REQ|REP,	NULL },
	{ "regress-user",	STRING,		config_parse_user,	REQ,		NULL },
	{ NULL,			0,		NULL,			0,		NULL },
};

struct config *
config_alloc(const char *mode)
{
	struct config *config;

	config = calloc(1, sizeof(*config));
	if (config == NULL)
		err(1, NULL);
	TAILQ_INIT(&config->cf_variables);

	config->cf_mode = config_mode(mode);
	switch (config->cf_mode) {
	case CONFIG_ROBSD:
		config->cf_path = "/etc/robsd.conf";
		config->cf_grammar = robsd;
		break;
	case CONFIG_ROBSD_CROSS:
		config->cf_path = "/etc/robsd-cross.conf";
		config->cf_grammar = robsd_cross;
		break;
	case CONFIG_ROBSD_PORTS:
		config->cf_path = "/etc/robsd-ports.conf";
		config->cf_grammar = robsd_ports;
		break;
	case CONFIG_ROBSD_REGRESS:
		config->cf_path = "/etc/robsd-regress.conf";
		config->cf_grammar = robsd_regress;
		break;
	case CONFIG_UNKNOWN:
		warnx("unknown mode '%s'", mode);
		config_free(config);
		return NULL;
	}

	return config;
}

int
config_parse(struct config *config, const char *path)
{
	if (path != NULL)
		config->cf_path = path;
	if (lexer_init(&config->cf_lx, config->cf_path))
		return 1;
	if (config_exec(config))
		return 1;
	return 0;
}

void
config_free(struct config *config)
{
	struct variable *va;

	if (config == NULL)
		return;

	lexer_free(&config->cf_lx);

	while ((va = TAILQ_FIRST(&config->cf_variables)) != NULL) {
		TAILQ_REMOVE(&config->cf_variables, va, va_entry);
		switch (va->va_type) {
		case INTEGER:
		case STRING:
		case DIRECTORY:
			break;
		case LIST:
			strings_free(va->va_list);
			break;
		}
		free(va->va_name);
		free(va);
	}

	free(config);
}

void
config_set_builddir(struct config *config, const char *builddir)
{
	config->cf_builddir = builddir;
}

int
config_append_string(struct config *config, const char *name, const char *val)
{
	char *p;

	if (grammar_find(config->cf_grammar, name))
		return 1;

	p = strdup(val);
	if (p == NULL)
		err(1, NULL);
	config_append(config, STRING, name, p, 0);
	return 0;
}

struct variable *
config_find(struct config *config, const char *name)
{
	return (struct variable *)config_findn(config, name, strlen(name));
}

int
config_validate(const struct config *config)
{
	int error = 0;
	int i;

	for (i = 0; config->cf_grammar[i].gr_kw != NULL; i++) {
		const struct grammar *gr = &config->cf_grammar[i];
		const char *str = gr->gr_kw;

		if ((gr->gr_flags & REQ) &&
		    !config_present(config, str)) {
			log_warnx(config->cf_path, 0,
			    "mandatory variable '%s' missing", str);
			error = 1;
		}

		if (gr->gr_type == DIRECTORY &&
		    config_validate_directory(config, str))
			error = 1;
	}

	return error;
}

int
config_interpolate(struct config *config)
{
	FILE *fh = stdin;
	char *buf = NULL;
	size_t bufsiz = 0;
	int error = 0;
	int lno = 0;

	if (config_append_defaults(config))
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
		line = config_interpolate_str(config, buf, "/dev/stdin", ++lno);
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
config_interpolate_str(const struct config *config, const char *str,
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

		va = config_findn(config, vs, len);
		if (va == NULL) {
			log_warnx(path, lno,
			    "invalid substitution, unknown variable '%.*s'",
			    (int)len, vs);
			goto out;
		}

		buffer_append(buf, str, p - str);

		switch (va->va_type) {
		case INTEGER:
			buffer_appendv(buf, "%d", va->va_int);
			break;

		case STRING:
		case DIRECTORY: {
			char *vp;

			vp = config_interpolate_str(config, va->va_str,
			    path, lno);
			if (vp == NULL)
				goto out;
			buffer_appendv(buf, "%s", vp);
			free(vp);
			break;
		}

		case LIST: {
			const struct string *st;

			TAILQ_FOREACH(st, va->va_list, st_entry) {
				char *vp;

				vp = config_interpolate_str(config, st->st_val,
				    path, lno);
				if (vp == NULL)
					goto out;
				buffer_appendv(buf, "%s%s", vp,
				    TAILQ_LAST(va->va_list, string_list) == st
				    ? "" : " ");
				free(vp);
			}
			break;
		}
		}

		str = &ve[1];
	}
	/* Output any remaining tail. */
	buffer_append(buf, str, strlen(str));

	buffer_appendc(buf, '\0');
	bp = buffer_release(buf);
out:
	buffer_free(buf);
	return bp;
}

const struct string_list *
variable_list(const struct variable *va)
{
	assert(va->va_type == LIST);
	return va->va_list;
}

static int
config_mode(const char *mode)
{
	if (strcmp(mode, "robsd") == 0)
		return CONFIG_ROBSD;
	if (strcmp(mode, "robsd-cross") == 0)
		return CONFIG_ROBSD_CROSS;
	if (strcmp(mode, "robsd-ports") == 0)
		return CONFIG_ROBSD_PORTS;
	if (strcmp(mode, "robsd-regress") == 0)
		return CONFIG_ROBSD_REGRESS;
	return CONFIG_UNKNOWN;
}

static int
config_exec(struct config *config)
{
	struct token *tk;
	int error = 0;

	memset(&tk, 0, sizeof(tk));

	for (;;) {
		if (lexer_peek(&config->cf_lx, TOKEN_EOF))
			break;
		if (!lexer_expect(&config->cf_lx, TOKEN_KEYWORD, &tk)) {
			error = 1;
			break;
		}

		switch (config_exec1(config, tk)) {
		case 1:
			error = 1;
			break;
		case -1:
			error = 1;
			goto out;
		}
	}

out:
	if (config->cf_lx.lx_err > 0)
		return 1;
	return error;
}

static int
config_exec1(struct config *config, struct token *tk)
{
	const struct grammar *gr;
	void *val;
	int error = 0;

	gr = grammar_find(config->cf_grammar, tk->tk_str);
	if (gr == NULL) {
		lexer_warnx(&config->cf_lx, tk->tk_lno, "unknown keyword '%s'",
		    tk->tk_str);
		return -1;
	}

	if ((gr->gr_flags & REP) == 0 && config_present(config, tk->tk_str)) {
		lexer_warnx(&config->cf_lx, tk->tk_lno,
		    "variable '%s' already defined", tk->tk_str);
		error = 1;
	}
	if (gr->gr_fn(config, tk, &val) == 0) {
		if (val != NULL)
			config_append(config, gr->gr_type, tk->tk_str, val,
			    tk->tk_lno);
	} else {
		error = 1;
	}

	return error;
}

static int
config_parse_boolean(struct config *config, struct token *UNUSED(kw),
    void **val)
{
	struct token *tk;

	if (!lexer_expect(&config->cf_lx, TOKEN_BOOLEAN, &tk))
		return 1;
	*val = (void *)tk->tk_int;
	return 0;
}

static int
config_parse_string(struct config *config, struct token *UNUSED(kw), void **val)
{
	struct token *tk;

	if (!lexer_expect(&config->cf_lx, TOKEN_STRING, &tk))
		return 1;
	*val = tk->tk_str;
	return 0;
}

static int
config_parse_integer(struct config *config, struct token *UNUSED(kw),
    void **val)
{
	struct token *tk;

	if (!lexer_expect(&config->cf_lx, TOKEN_INTEGER, &tk))
		return 1;
	*val = (void *)tk->tk_int;
	return 0;
}

static int
config_parse_glob(struct config *config, struct token *UNUSED(kw), void **val)
{
	glob_t g;
	struct token *tk;
	struct string_list *strings = NULL;
	size_t i;
	int error;

	if (!lexer_expect(&config->cf_lx, TOKEN_STRING, &tk))
		return 1;
	error = glob(tk->tk_str, GLOB_NOCHECK, NULL, &g);
	if (error) {
		lexer_warn(&config->cf_lx, tk->tk_lno, "glob: %d", error);
		goto out;
	}

	strings = strings_alloc();
	for (i = 0; i < g.gl_matchc; i++)
		strings_append(strings, g.gl_pathv[i]);

out:
	globfree(&g);
	*val = strings;
	return 0;
}

static int
config_parse_list(struct config *config, struct token *UNUSED(kw), void **val)
{
	struct string_list *strings = NULL;
	struct token *tk;

	if (!lexer_expect(&config->cf_lx, TOKEN_LBRACE, &tk))
		return 1;
	strings = strings_alloc();
	for (;;) {
		char *str;

		if (lexer_peek(&config->cf_lx, TOKEN_RBRACE))
			break;
		if (!lexer_expect(&config->cf_lx, TOKEN_STRING, &tk))
			goto err;
		str = strdup(tk->tk_str);
		if (str == NULL)
			err(1, NULL);
		strings_append(strings, str);
	}
	if (!lexer_expect(&config->cf_lx, TOKEN_RBRACE, &tk))
		goto err;

	*val = strings;
	return 0;

err:
	strings_free(strings);
	return 1;
}

static int
config_parse_user(struct config *config, struct token *kw, void **val)
{
	char *user;

	if (config_parse_string(config, kw, (void **)&user))
		return 1;
	if (getpwnam(user) == NULL) {
		lexer_warnx(&config->cf_lx, kw->tk_lno, "user '%s' not found",
		    user);
		return 1;
	}

	*val = user;
	return 0;
}

static int
config_parse_regress(struct config *config, struct token *UNUSED(kw),
    void **val)
{
	struct lexer *lx = &config->cf_lx;
	struct token *tk;
	struct variable *regress;
	const char *path;

	if (!lexer_expect(lx, TOKEN_STRING, &tk))
		return 1;
	path = tk->tk_str;

	for (;;) {
		char name[128];

		if (lexer_if(lx, TOKEN_ENV, &tk)) {
			struct token_list *env;

			if (config_parse_list(config, tk, (void **)&env))
				return 1;
			if (regressname(name, sizeof(name), path, "env")) {
				lexer_warnx(lx, tk->tk_lno, "name too long");
				return 1;
			}
			config_append(config, LIST, name, env, tk->tk_lno);
		} else if (lexer_if(lx, TOKEN_QUIET, &tk)) {
			if (regressname(name, sizeof(name), path, "quiet")) {
				lexer_warnx(lx, tk->tk_lno, "name too long");
				return 1;
			}
			config_append(config, INTEGER, name, (void *)1,
			    tk->tk_lno);
		} else if (lexer_if(lx, TOKEN_ROOT, &tk)) {
			if (regressname(name, sizeof(name), path, "root")) {
				lexer_warnx(lx, tk->tk_lno, "name too long");
				return 1;
			}
			config_append(config, INTEGER, name, (void *)1,
			    tk->tk_lno);
		} else {
			break;
		}
	}

	regress = config_find(config, "regress");
	if (regress == NULL)
		regress = config_append(config, LIST, "regress",
		    strings_alloc(), 0);
	strings_append(regress->va_list, path);

	*val = NULL;
	return 0;
}

/*
 * Append read-only variables accessible during interpolation.
 */
static int
config_append_defaults(struct config *cf)
{
	char *str;

	if (cf->cf_mode == CONFIG_ROBSD_REGRESS) {
		str = ifgrinet("egress");
		if (str == NULL)
			return 1;
		config_append(cf, STRING, "inet", str, 0);
	}

	if (cf->cf_mode == CONFIG_ROBSD_CROSS &&
	    cf->cf_builddir != NULL) {
		/*
		 * Ignore errors as the configuration is loaded before the
		 * target file is created.
		 */
		str = crosstarget(cf->cf_builddir);
		if (str != NULL)
			config_append(cf, STRING, "target", str, 0);
	}

	str = config_interpolate_str(cf, "${robsddir}/attic", cf->cf_path, 0);
	if (str == NULL)
		return 1;
	config_append(cf, STRING, "keep-dir", str, 0);

	return 0;
}

static struct variable *
config_append(struct config *config, enum variable_type type, const char *name,
    void *val, int lno)
{
	struct variable *va;

	va = calloc(1, sizeof(*va));
	if (va == NULL)
		err(1, NULL);
	va->va_type = type;
	va->va_lno = lno;
	va->va_name = strdup(name);
	if (va->va_name == NULL)
		err(1, NULL);
	va->va_namelen = strlen(name);
	va->va_val = val;
	TAILQ_INSERT_TAIL(&config->cf_variables, va, va_entry);
	return va;
}

static const struct variable *
config_findn(const struct config *config, const char *name, size_t namelen)
{
	static struct variable vadef;
	const struct variable *va;
	int i;

	TAILQ_FOREACH(va, &config->cf_variables, va_entry) {
		if (va->va_namelen == namelen &&
		    strncmp(va->va_name, name, namelen) == 0)
			return va;
	}

	/* Look for default value. */
	for (i = 0; config->cf_grammar[i].gr_kw != NULL; i++) {
		const struct grammar *gr = &config->cf_grammar[i];
		void *val;

		if (strncmp(gr->gr_kw, name, namelen) != 0 ||
		    (gr->gr_flags & REQ))
			continue;

		memset(&vadef, 0, sizeof(vadef));
		vadef.va_type = gr->gr_type;
		val = gr->gr_default;
		switch (vadef.va_type) {
		case INTEGER:
			vadef.va_int = 0;
			break;

		case STRING:
		case DIRECTORY:
			vadef.va_val = val == NULL ? "" : val;
			break;

		case LIST: {
			static struct string_list def;

			TAILQ_INIT(&def);
			vadef.va_val = &def;
		}
		}
		return &vadef;
	}

	return NULL;
}

static int
config_present(const struct config *config, const char *name)
{
	const struct variable *va;

	TAILQ_FOREACH(va, &config->cf_variables, va_entry) {
		if (strcmp(va->va_name, name) == 0)
			return 1;
	}
	return 0;
}

static int
config_validate_directory(const struct config *config, const char *name)
{
	struct stat st;
	const struct variable *va;
	char *path;
	int error = 0;

	va = config_findn(config, name, strlen(name));
	if (va == NULL)
		return 0;
	/* Empty string error already reported by the lexer. */
	if (strlen(va->va_str) == 0)
		return 0;

	path = config_interpolate_str(config, va->va_str, config->cf_path,
	    va->va_lno);
	if (path == NULL) {
		error = 1;
	} else if (stat(path, &st) == -1) {
		log_warn(config->cf_path, va->va_lno, "%s",
		    path);
		error = 1;
	} else if (!S_ISDIR(st.st_mode)) {
		log_warnx(config->cf_path, va->va_lno,
		    "%s: is not a directory", path);
		error = 1;
	}
	free(path);

	return error;
}

/*
 * Read the cross target from the file located in the build directory created by
 * robsd-cross.
 */
static char *
crosstarget(const char *builddir)
{
	char path[PATH_MAX];
	char *buf = NULL;
	char *target = NULL;
	FILE *fh;
	ssize_t pathsiz;
	size_t bufsiz = 0;
	size_t len;
	int n;

	pathsiz = sizeof(path);
	n = snprintf(path, pathsiz, "%s/target", builddir);
	if (n < 0 || n >= pathsiz) {
		warnc(ENAMETOOLONG, "%s", __func__);
		return NULL;
	}

	fh = fopen(path, "r");
	if (fh == NULL) {
		if (errno != ENOENT)
			warn("%s", path);
		return NULL;
	}
	if (getline(&buf, &bufsiz, fh) == -1) {
		warn("%s", path);
		goto out;
	}

	len = strlen(buf);
	if (len == 0) {
		warnx("%s: empty", path);
		free(buf);
		goto out;
	}
	buf[len - 1] = '\0';
	target = buf;

out:
	fclose(fh);
	return target;
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
