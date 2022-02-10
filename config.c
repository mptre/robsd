#include <sys/queue.h>

#include <assert.h>
#include <ctype.h>
#include <err.h>
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
	const char	*lx_path;
	FILE		*lx_fh;
	int		 lx_lno;
};

struct token {
	enum token_type {
		TOKEN_EOF,
		TOKEN_LBRACE,
		TOKEN_RBRACE,
		TOKEN_KEYWORD,
		TOKEN_BOOLEAN,
		TOKEN_INTEGER,
		TOKEN_STRING,
		TOKEN_UNKNOWN,
	} tk_type;

	union {
		char	*tk_str;
		int64_t	 tk_int;
	};
};

static int	lexer_init(struct lexer *, const char *);
static void	lexer_free(struct lexer *);
static int	lexer_getc(struct lexer *, char *);
static void	lexer_ungetc(struct lexer *, char);
static int	lexer_read(struct lexer *, struct token *);
static int	lexer_expect(struct lexer *, enum token_type, struct token *);
static int	lexer_peek(struct lexer *, enum token_type);

static void	lexer_warn(const struct lexer *, const char *, ...)
	__attribute__((format(printf, 2, 3)));
static void	lexer_warnx(const struct lexer *, const char *, ...)
	__attribute__((format(printf, 2, 3)));

static void		 token_free(struct token *);
static const char	*tokenstr(enum token_type);

static int
lexer_init(struct lexer *lx, const char *path)
{
	lx->lx_fh = fopen(path, "r");
	if (lx->lx_fh == NULL) {
		warn("open: %s", path);
		return 1;
	}
	lx->lx_path = path;
	lx->lx_lno = 1;
	return 0;
}

static void
lexer_free(struct lexer *lx)
{
	if (lx == NULL)
		return;

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
			lexer_warn(lx, "fgetc");
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
		lexer_warnx(lx, "token too long");			\
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
					lexer_warnx(lx, "integer too big");
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
				lexer_warnx(lx, "unterminated string");
				return 1;
			}
			if (ch == '"')
				break;
			CONSUME(ch);
		}
		if (buflen == 0)
			lexer_warnx(lx, "empty string");
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
lexer_expect(struct lexer *lx, enum token_type type, struct token *tk)
{
	if (lexer_read(lx, tk))
		return 0;
	if (type != tk->tk_type) {
		lexer_warnx(lx, "want %s, got %s", tokenstr(type),
		    tokenstr(tk->tk_type));
		token_free(tk);
		return 0;
	}
	return 1;
}

static int
lexer_peek(struct lexer *lx, enum token_type type)
{
	struct token tk;
	fpos_t pos;
	int lno, peek;

	lno = lx->lx_lno;
	if (fgetpos(lx->lx_fh, &pos))
		return 0;
	if (lexer_read(lx, &tk))
		return 0;
	(void)fsetpos(lx->lx_fh, &pos);
	lx->lx_lno = lno;
	peek = tk.tk_type == type;
	token_free(&tk);
	return peek;
}

static void
lexer_warn(const struct lexer *lx, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	logv(warn, lx->lx_path, lx->lx_lno, fmt, ap);
	va_end(ap);
}

static void
lexer_warnx(const struct lexer *lx, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	logv(warnx, lx->lx_path, lx->lx_lno, fmt, ap);
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
	case TOKEN_BOOLEAN:
	case TOKEN_INTEGER:
	case TOKEN_UNKNOWN:
		break;
	}
	memset(tk, 0, sizeof(*tk));
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
 * variables ----------------------------------------------------------------------
 */

struct variable {
	char	*va_name;
	size_t	 va_namelen;
	union {
		void			*va_val;
		char			*va_str;
		struct string_list	*va_list;
		int			 va_int;
	};

	enum variable_type {
		INTEGER,
		STRING,
		LIST,
	} va_type;

	TAILQ_ENTRY(variable)	va_entry;
};

TAILQ_HEAD(variable_list, variable);

/*
 * grammar ---------------------------------------------------------------------
 */

struct grammar {
	const char		*gr_kw;
	enum variable_type	 gr_type;
	int			 (*gr_fn)(struct config *, void **);
	unsigned int		 gr_flags;
#define MANDATORY	0x00000001u

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
 * config -------------------------------------------------------------------------
 */

struct config {
	struct lexer		 cf_lx;
	struct variable_list	 cf_variables;
	const struct grammar	*cf_grammar;
	const char		*cf_path;
	enum {
		CONFIG_ROBSD,
		CONFIG_ROBSD_PORTS,
		CONFIG_ROBSD_REGRESS,
	} cf_mode;
};

static int	config_mode(const char *);

static int	config_exec(struct config *);
static int	config_exec1(struct config *, const char *);
static int	config_parse_boolean(struct config *, void **);
static int	config_parse_string(struct config *, void **);
static int	config_parse_integer(struct config *, void **);
static int	config_parse_glob(struct config *, void **);
static int	config_parse_dir(struct config *, void **);
static int	config_parse_list(struct config *, void **);
static int	config_parse_user(struct config *, void **);
static int	config_parse_regress(struct config *, void **);

static void			 config_append(struct config *,
    enum variable_type, const char *, void *);
static const struct variable	*config_findn(const struct config *,
    const char *, size_t);
static int			 config_present(const struct config *,
    const char *);

static const struct grammar robsd[] = {
	{ "robsddir",		STRING,		config_parse_dir,	MANDATORY,	NULL },
	{ "builduser",		STRING,		config_parse_user,	0,		"build" },
	{ "destdir",		STRING,		config_parse_dir,	MANDATORY,	NULL },
	{ "execdir",		STRING,		config_parse_dir,	0,		"/usr/local/libexec/robsd" },
	{ "hook",		LIST,		config_parse_list,	0,		NULL },
	{ "keep",		INTEGER,	config_parse_integer,	0,		NULL },
	{ "reboot",		INTEGER,	config_parse_boolean,	0,		NULL },
	{ "skip",		LIST,		config_parse_list,	0,		NULL },
	{ "bsd-diff",		LIST,		config_parse_glob,	0,		NULL },
	{ "bsd-objdir",		STRING,		config_parse_dir,	0,		"/usr/obj" },
	{ "bsd-srcdir",		STRING,		config_parse_dir,	0,		"/usr/src" },
	{ "cvs-root",		STRING,		config_parse_string,	0,		NULL },
	{ "cvs-user",		STRING,		config_parse_user,	0,		NULL },
	{ "distrib-host",	STRING,		config_parse_string,	0,		NULL },
	{ "distrib-path",	STRING,		config_parse_string,	0,		NULL },
	{ "distrib-signify",	STRING,		config_parse_string,	0,		NULL },
	{ "distrib-user",	STRING,		config_parse_user,	0,		NULL },
	{ "x11-diff",		LIST,		config_parse_glob,	0,		NULL },
	{ "x11-objdir",		STRING,		config_parse_dir,	0,		"/usr/xobj" },
	{ "x11-srcdir",		STRING,		config_parse_dir,	0,		"/usr/xenocara" },
	{ NULL,			0,		NULL,			0,		NULL },
};

static const struct grammar robsd_ports[] = {
	{ "robsddir",		STRING,		config_parse_dir,	MANDATORY,	NULL },
	{ "chroot",		STRING,		config_parse_string,	MANDATORY,	NULL },
	{ "execdir",		STRING,		config_parse_dir,	0,		"/usr/local/libexec/robsd" },
	{ "hook",		LIST,		config_parse_list,	0,		NULL },
	{ "keep",		INTEGER,	config_parse_integer,	0,		NULL },
	{ "skip",		LIST,		config_parse_list,	0,		NULL },
	{ "cvs-root",		STRING,		config_parse_string,	0,		NULL },
	{ "cvs-user",		STRING,		config_parse_user,	0,		NULL },
	{ "distrib-host",	STRING,		config_parse_string,	0,		NULL },
	{ "distrib-path",	STRING,		config_parse_string,	0,		NULL },
	{ "distrib-signify",	STRING,		config_parse_string,	0,		NULL },
	{ "distrib-user",	STRING,		config_parse_user,	0,		NULL },
	{ "ports",		LIST,		config_parse_list,	MANDATORY,	NULL },
	{ "ports-diff",		LIST,		config_parse_glob,	0,		NULL },
	{ "ports-dir",		STRING,		config_parse_string,	0,		"/usr/ports" },
	{ "ports-user",		STRING,		config_parse_user,	MANDATORY,	NULL },
	{ NULL,			0,		NULL,			0,		NULL },
};

static const struct grammar robsd_regress[] = {
	{ "robsddir",		STRING,		config_parse_dir,	MANDATORY,	NULL },
	{ "execdir",		STRING,		config_parse_dir,	0,		"/usr/local/libexec/robsd" },
	{ "hook",		LIST,		config_parse_list,	0,		NULL },
	{ "keep",		INTEGER,	config_parse_integer,	0,		NULL },
	{ "rdonly",		INTEGER,	config_parse_boolean,	0,		NULL },
	{ "sudo",		STRING,		config_parse_string,	0,		"doas -n" },
	{ "bsd-diff",		LIST,		config_parse_glob,	0,		NULL },
	{ "bsd-srcdir",		STRING,		config_parse_dir,	0,		"/usr/src" },
	{ "cvs-user",		STRING,		config_parse_user,	0,		NULL },
	{ "regress",		LIST,		config_parse_regress,	MANDATORY,	NULL },
	{ "regress-user",	STRING,		config_parse_user,	MANDATORY,	NULL },
	{ NULL,			0,		NULL,			0,		NULL },
};

struct config *
config_alloc(void)
{
	struct config *config;
	int mode;

	config = calloc(1, sizeof(*config));
	if (config == NULL)
		err(1, NULL);
	TAILQ_INIT(&config->cf_variables);

	mode = config_mode(getprogname());
	if (mode == -1) {
		const char *progname;

		/*
		 * Testing backdoor, but since _MODE is exported under normal executing
		 * as well give the actual program name higher precedence.
		 */
		progname = getenv("_MODE");
		if (progname != NULL)
			mode = config_mode(progname);
	}
	if (mode == -1)
		mode = CONFIG_ROBSD;
	switch (mode) {
	case CONFIG_ROBSD:
		config->cf_path = "/etc/robsd.conf";
		config->cf_grammar = robsd;
		break;
	case CONFIG_ROBSD_PORTS:
		config->cf_path = "/etc/robsd-ports.conf";
		config->cf_grammar = robsd_ports;
		break;
	case CONFIG_ROBSD_REGRESS:
		config->cf_path = "/etc/robsd-regress.conf";
		config->cf_grammar = robsd_regress;
		break;
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
			break;
		case STRING:
			free(va->va_str);
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

int
config_append_string(struct config *config, const char *name, const char *val)
{
	char *p;

	if (grammar_find(config->cf_grammar, name))
		return 1;

	p = strdup(val);
	if (p == NULL)
		err(1, NULL);
	config_append(config, STRING, name, p);
	return 0;
}

const struct variable *
config_find(const struct config *config, const char *name)
{
	return config_findn(config, name, strlen(name));
}

int
config_validate(const struct config *config)
{
	int error = 0;
	int i;

	for (i = 0; config->cf_grammar[i].gr_kw != NULL; i++) {
		const struct grammar *gr = &config->cf_grammar[i];
		const char *str = gr->gr_kw;

		if ((gr->gr_flags & MANDATORY) == 0 ||
		    config_present(config, str))
			continue;

		log_warnx(config->cf_path, 0,
		    "mandatory variable '%s' missing", str);
		error = 1;
	}

	return error;
}

int
config_interpolate(const struct config *config)
{
	FILE *fh = stdin;
	char *buf = NULL;
	size_t bufsiz = 0;
	int error = 0;
	int lno = 0;

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
		line = config_interpolate_str(config, buf, ++lno);
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
config_interpolate_str(const struct config *config, const char *str, int lno)
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
			log_warnx("/dev/stdin", lno,
			    "invalid substitution, expected '{'");
			goto out;
		}
		vs += 1;
		ve = strchr(vs, '}');
		if (ve == NULL) {
			log_warnx("/dev/stdin", lno,
			    "invalid substitution, expected '}'");
			goto out;
		}
		len = ve - vs;
		if (len == 0) {
			log_warnx("/dev/stdin", lno,
			    "invalid substitution, empty variable name");
			goto out;
		}

		va = config_findn(config, vs, len);
		if (va == NULL) {
			log_warnx("/dev/stdin", lno,
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
			buffer_appendv(buf, "%s", va->va_str);
			break;

		case LIST: {
			const struct string *st;

			TAILQ_FOREACH(st, va->va_list, st_entry) {
				buffer_appendv(buf, "%s%s", st->st_val,
				    TAILQ_LAST(va->va_list, string_list) == st
				    ? "" : " ");
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
config_mode(const char *progname)
{
	if (strncmp(progname, "robsd-ports", 11) == 0)
		return CONFIG_ROBSD_PORTS;
	else if (strncmp(progname, "robsd-regress", 13) == 0)
		return CONFIG_ROBSD_REGRESS;
	return -1;
}

static int
config_exec(struct config *config)
{
	struct token tk;
	int error = 0;

	memset(&tk, 0, sizeof(tk));

	for (;;) {
		if (lexer_peek(&config->cf_lx, TOKEN_EOF))
			break;
		if (!lexer_expect(&config->cf_lx, TOKEN_KEYWORD, &tk)) {
			error = 1;
			break;
		}

		switch (config_exec1(config, tk.tk_str)) {
		case 1:
			error = 1;
			break;
		case -1:
			error = 1;
			goto out;
		}

		token_free(&tk);
	}

out:
	token_free(&tk);
	return error;
}

static int
config_exec1(struct config *config, const char *name)
{
	const struct grammar *gr;
	void *val;
	int error = 0;

	gr = grammar_find(config->cf_grammar, name);
	if (gr == NULL) {
		lexer_warnx(&config->cf_lx, "unknown keyword '%s'", name);
		return -1;
	}

	if (config_present(config, name)) {
		lexer_warnx(&config->cf_lx,
		    "variable '%s' already defined", name);
		error = 1;
	}
	if (gr->gr_fn(config, &val) == 0)
		config_append(config, gr->gr_type, name, val);
	else
		error = 1;

	return error;
}

static int
config_parse_boolean(struct config *config, void **val)
{
	struct token tk;

	if (!lexer_expect(&config->cf_lx, TOKEN_BOOLEAN, &tk))
		return 1;
	*val = (void *)tk.tk_int;
	return 0;
}

static int
config_parse_string(struct config *config, void **val)
{
	struct token tk;

	if (!lexer_expect(&config->cf_lx, TOKEN_STRING, &tk))
		return 1;
	*val = tk.tk_str;
	return 0;
}

static int
config_parse_integer(struct config *config, void **val)
{
	struct token tk;

	if (!lexer_expect(&config->cf_lx, TOKEN_INTEGER, &tk))
		return 1;
	*val = (void *)tk.tk_int;
	return 0;
}

static int
config_parse_glob(struct config *config, void **val)
{
	glob_t g;
	struct token tk;
	struct string_list *strings = NULL;
	size_t i;
	int error;

	if (!lexer_expect(&config->cf_lx, TOKEN_STRING, &tk))
		return 1;
	error = glob(tk.tk_str, GLOB_NOCHECK, NULL, &g);
	if (error) {
		lexer_warn(&config->cf_lx, "glob: %d", error);
		goto out;
	}

	strings = strings_alloc();
	for (i = 0; i < g.gl_matchc; i++)
		strings_append(strings, g.gl_pathv[i]);

out:
	token_free(&tk);
	globfree(&g);
	*val = strings;
	return 0;
}

static int
config_parse_dir(struct config *config, void **val)
{
	struct stat st;
	struct token tk;

	if (!lexer_expect(&config->cf_lx, TOKEN_STRING, &tk))
		return 1;
	if (stat(tk.tk_str, &st) == -1) {
		lexer_warn(&config->cf_lx, "%s", tk.tk_str);
		token_free(&tk);
		return 1;
	}
	if (!S_ISDIR(st.st_mode)) {
		lexer_warnx(&config->cf_lx, "%s: is not a directory",
		    tk.tk_str);
		token_free(&tk);
		return 1;
	}

	*val = tk.tk_str;
	return 0;
}

static int
config_parse_list(struct config *config, void **val)
{
	struct token tk;
	struct string_list *strings = NULL;

	if (!lexer_expect(&config->cf_lx, TOKEN_LBRACE, &tk))
		return 1;
	strings = strings_alloc();
	for (;;) {
		if (lexer_peek(&config->cf_lx, TOKEN_RBRACE))
			break;
		if (!lexer_expect(&config->cf_lx, TOKEN_STRING, &tk))
			goto err;
		strings_append(strings, tk.tk_str);
		token_free(&tk);
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
config_parse_user(struct config *config, void **val)
{
	char *user;

	if (config_parse_string(config, (void **)&user))
		return 1;
	if (getpwnam(user) == NULL) {
		lexer_warnx(&config->cf_lx, "user '%s' not found", user);
		free(user);
		return 1;
	}

	*val = user;
	return 0;
}

static int
config_parse_regress(struct config *config, void **val)
{
	struct string_list *regress, *root, *skip;
	struct string *st;

	if (config_parse_list(config, (void **)&regress))
		return 1;

	root = strings_alloc();
	skip = strings_alloc();

	TAILQ_FOREACH(st, regress, st_entry) {
		char *p;

		p = strchr(st->st_val, ':');
		if (p == NULL)
			continue;

		*p++ = '\0';
		if (*p == '\0') {
			lexer_warnx(&config->cf_lx, "empty regress flags");
			continue;
		}
		for (; *p != '\0'; p++) {
			switch (*p) {
			case 'R':
				strings_append(root, st->st_val);
				break;
			case 'S':
				strings_append(skip, st->st_val);
				break;
			default:
				lexer_warnx(&config->cf_lx,
				    "unknown regress flag '%c'", *p);
			}
		}
	}

	config_append(config, LIST, "regress-root", root);
	config_append(config, LIST, "regress-skip", skip);

	*val = regress;
	return 0;
}

static void
config_append(struct config *config, enum variable_type type, const char *name,
    void *val)
{
	struct variable *va;

	va = calloc(1, sizeof(*va));
	if (va == NULL)
		err(1, NULL);
	va->va_type = type;
	va->va_name = strdup(name);
	if (va->va_name == NULL)
		err(1, NULL);
	va->va_namelen = strlen(name);
	va->va_val = val;
	TAILQ_INSERT_TAIL(&config->cf_variables, va, va_entry);
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
		    (gr->gr_flags & MANDATORY))
			continue;

		memset(&vadef, 0, sizeof(vadef));
		vadef.va_type = gr->gr_type;
		val = gr->gr_default;
		switch (vadef.va_type) {
		case INTEGER:
			vadef.va_int = 0;
			break;

		case STRING:
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
