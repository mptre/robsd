#include <sys/queue.h>
#include <sys/stat.h>

#include <ctype.h>
#include <err.h>
#include <errno.h>
#include <glob.h>
#include <limits.h>
#include <pwd.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/*
 * variables ----------------------------------------------------------------------
 */

struct grammar;
struct string_list;

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

static void			 variables_append(struct variable_list *,
    enum variable_type, const char *, void *);
static void			 variables_free(struct variable_list *);
static int			 variables_validate(
    const struct variable_list *, const struct grammar *, const char *);
static int			 variables_interpolate(struct variable_list *,
    const struct grammar *);
static int			 variables_interpolate1(struct variable_list *,
    const struct grammar *, const char *, int);
static const struct variable	*variables_find(struct variable_list *,
    const struct grammar *, const char *, size_t);
static int			 variables_present(const struct variable_list *,
    const char *);

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

/*
 * parser ----------------------------------------------------------------------
 */

struct parser {
	struct lexer	pr_lx;
};

static int	parser_exec(struct parser *, struct variable_list *,
    const struct grammar *);
static int	parser_exec1(struct parser *, struct variable_list *,
    const struct grammar *, const char *);
static int	parser_boolean(struct parser *, struct variable_list *,
    void **);
static int	parser_string(struct parser *, struct variable_list *, void **);
static int	parser_integer(struct parser *, struct variable_list *,
    void **);
static int	parser_glob(struct parser *, struct variable_list *, void **);
static int	parser_dir(struct parser *, struct variable_list *, void **);
static int	parser_list(struct parser *, struct variable_list *, void **);
static int	parser_user(struct parser *, struct variable_list *, void **);
static int	parser_regress(struct parser *, struct variable_list *,
    void **);

/*
 * grammar ---------------------------------------------------------------------
 */

struct grammar {
	const char		*gr_kw;
	enum variable_type	 gr_type;
	int			 (*gr_fn)(struct parser *,
	    struct variable_list *, void **);
	unsigned int		 gr_flags;
#define MANDATORY	0x00000001u

	void			*gr_default;
};

/*
 * strings ---------------------------------------------------------------------
 */

struct string {
	char			*st_val;
	TAILQ_ENTRY(string)	 st_entry;
};

TAILQ_HEAD(string_list, string);

static struct string_list	*strings_alloc(void);
static void			 strings_free(struct string_list *);
static void			 strings_append(struct string_list *, char *);

/*
 * main ------------------------------------------------------------------------
 */

#define UNUSED(x)	_##x __attribute__((__unused__))

static void	log_warnx(const char *, int, const char *, ...)
	__attribute__((format(printf, 3, 4)));
static void	logv(void (*)(const char *, ...), const char *, int,
    const char *, va_list);

static void		progmode(char *, size_t, const struct grammar **);
static int		progmode1(const char *, char *, size_t,
    const struct grammar **);
static __dead void	usage(void);

static const struct grammar robsd[] = {
	{ "robsddir",		STRING,		parser_dir,	MANDATORY,	NULL },
	{ "builduser",		STRING,		parser_user,	0,		"build" },
	{ "destdir",		STRING,		parser_dir,	MANDATORY,	NULL },
	{ "execdir",		STRING,		parser_dir,	0,		"/usr/local/libexec/robsd" },
	{ "hook",		STRING,		parser_string,	0,		NULL },
	{ "keep",		INTEGER,	parser_integer,	0,		NULL },
	{ "reboot",		INTEGER,	parser_boolean,	0,		NULL },
	{ "skip",		LIST,		parser_list,	0,		NULL },
	{ "bsd-diff",		LIST,		parser_glob,	0,		NULL },
	{ "bsd-objdir",		STRING,		parser_dir,	0,		"/usr/obj" },
	{ "bsd-srcdir",		STRING,		parser_dir,	0,		"/usr/src" },
	{ "cvs-root",		STRING,		parser_string,	0,		NULL },
	{ "cvs-user",		STRING,		parser_user,	0,		NULL },
	{ "distrib-host",	STRING,		parser_string,	0,		NULL },
	{ "distrib-path",	STRING,		parser_string,	0,		NULL },
	{ "distrib-signify",	STRING,		parser_string,	0,		NULL },
	{ "distrib-user",	STRING,		parser_user,	0,		NULL },
	{ "x11-diff",		LIST,		parser_glob,	0,		NULL },
	{ "x11-objdir",		STRING,		parser_dir,	0,		"/usr/xobj" },
	{ "x11-srcdir",		STRING,		parser_dir,	0,		"/usr/xenocara" },
	{ NULL,			0,		NULL,		0,		NULL },
};

static const struct grammar robsd_ports[] = {
	{ "robsddir",		STRING,		parser_dir,	MANDATORY,	NULL },
	{ "chroot",		STRING,		parser_string,	MANDATORY,	NULL },
	{ "execdir",		STRING,		parser_dir,	0,		"/usr/local/libexec/robsd" },
	{ "hook",		STRING,		parser_string,	0,		NULL },
	{ "keep",		INTEGER,	parser_integer,	0,		NULL },
	{ "skip",		LIST,		parser_list,	0,		NULL },
	{ "cvs-root",		STRING,		parser_string,	0,		NULL },
	{ "cvs-user",		STRING,		parser_user,	0,		NULL },
	{ "distrib-host",	STRING,		parser_string,	0,		NULL },
	{ "distrib-path",	STRING,		parser_string,	0,		NULL },
	{ "distrib-signify",	STRING,		parser_string,	0,		NULL },
	{ "distrib-user",	STRING,		parser_user,	0,		NULL },
	{ "ports",		LIST,		parser_list,	MANDATORY,	NULL },
	{ "ports-diff",		LIST,		parser_glob,	0,		NULL },
	{ "ports-dir",		STRING,		parser_string,	0,		"/usr/ports" },
	{ "ports-user",		STRING,		parser_user,	MANDATORY,	NULL },
	{ NULL,			0,		NULL,		0,		NULL },
};

static const struct grammar robsd_regress[] = {
	{ "robsddir",		STRING,		parser_dir,	MANDATORY,	NULL },
	{ "execdir",		STRING,		parser_dir,	0,		"/usr/local/libexec/robsd" },
	{ "hook",		STRING,		parser_string,	0,		NULL },
	{ "keep",		INTEGER,	parser_integer,	0,		NULL },
	{ "rdonly",		INTEGER,	parser_boolean,	0,		NULL },
	{ "sudo",		STRING,		parser_string,	0,		"doas -n" },
	{ "bsd-diff",		LIST,		parser_glob,	0,		NULL },
	{ "bsd-srcdir",		STRING,		parser_dir,	0,		"/usr/src" },
	{ "cvs-user",		STRING,		parser_user,	0,		NULL },
	{ "regress",		LIST,		parser_regress,	MANDATORY,	NULL },
	{ "regress-user",	STRING,		parser_user,	MANDATORY,	NULL },
	{ NULL,			0,		NULL,		0,		NULL },
};

int
main(int argc, char *argv[])
{
	struct variable_list variables = TAILQ_HEAD_INITIALIZER(variables);
	char path[PATH_MAX];
	const struct grammar *grammar;
	struct parser pr;
	int ch, error;
	int dointerpolate = 0;

	if (pledge("stdio rpath getpw", NULL) == -1)
		err(1, "pledge");

	progmode(path, sizeof(path), &grammar);

	while ((ch = getopt(argc, argv, "f:")) != -1) {
		switch (ch) {
		case 'f': {
			int n;

			n = snprintf(path, sizeof(path), "%s", optarg);
			if (n < 0 || n >= (ssize_t)sizeof(path))
				errc(1, ENAMETOOLONG, "%s", optarg);
			break;
		}

		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;
	if (argc > 1)
		usage();
	if (argc == 1) {
		if (strcmp(argv[0], "-") == 0)
			dointerpolate = 1;
		else
			usage();
	}

	memset(&pr, 0, sizeof(pr));
	error = lexer_init(&pr.pr_lx, path);
	if (error)
		goto out;
	error = parser_exec(&pr, &variables, grammar);
	/* Keep going as we want to report as many errors as possible. */

	if (pledge("stdio", NULL) == -1)
		err(1, "pledge");

	if (variables_validate(&variables, grammar, path))
		error = 1;
	if (error)
		goto out;

	if (dointerpolate)
		error = variables_interpolate(&variables, grammar);

out:
	lexer_free(&pr.pr_lx);
	variables_free(&variables);
	return error;
}

static void
log_warnx(const char *path, int lno, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	logv(warnx, path, lno, fmt, ap);
	va_end(ap);
}

static void
logv(void (*pr)(const char *, ...), const char *path, int lno, const char *fmt,
    va_list ap)
{
	char msg[512], line[16];

	if (lno == 0)
		line[0] = '\0';
	else
		(void)snprintf(line, sizeof(line), "%d:", lno);

	(void)vsnprintf(msg, sizeof(msg), fmt, ap);
	(pr)("%s:%s %s", path, line, msg);
}

static void
progmode(char *buf, size_t bufsiz, const struct grammar **gr)
{
	const char *progname;

	if (progmode1(getprogname(), buf, bufsiz, gr))
		return;

	/*
	 * Testing backdoor, but since _MODE is exported under normal executing
	 * as well give the actual program name higher precedence.
	 */
	progname = getenv("_MODE");
	if (progname != NULL)
		progmode1(progname, buf, bufsiz, gr);
}

static int
progmode1(const char *progname, char *buf, size_t bufsiz,
    const struct grammar **gr)
{
	const char *path;
	int rv = 0;

	if (strncmp(progname, "robsd-ports", 11) == 0) {
		path = "/etc/robsd-ports.conf";
		*gr = robsd_ports;
		rv = 1;
	} else if (strncmp(progname, "robsd-regress", 13) == 0) {
		path = "/etc/robsd-regress.conf";
		*gr = robsd_regress;
		rv = 1;
	} else {
		path = "/etc/robsd.conf";
		*gr = robsd;
	}
	(void)snprintf(buf, bufsiz, "%s", path);
	return rv;
}

static __dead void
usage(void)
{
	fprintf(stderr, "usage: robsd-config [-n] [-f file] [-]\n");
	exit(1);
}

static void
variables_append(struct variable_list *variables, enum variable_type type,
    const char *name, void *val)
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
	TAILQ_INSERT_TAIL(variables, va, va_entry);
}

static void
variables_free(struct variable_list *variables)
{
	struct variable *va;

	while ((va = TAILQ_FIRST(variables)) != NULL) {
		TAILQ_REMOVE(variables, va, va_entry);
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
}

static int
variables_validate(const struct variable_list *variables,
    const struct grammar *grammar, const char *path)
{
	int error = 0;
	int i;

	for (i = 0; grammar[i].gr_kw != NULL; i++) {
		const char *str = grammar[i].gr_kw;

		if ((grammar[i].gr_flags & MANDATORY) == 0 ||
		    variables_present(variables, str))
			continue;

		log_warnx(path, 0, "mandatory variable '%s' missing", str);
		error = 1;
	}

	return error;
}

static int
variables_interpolate(struct variable_list *variables,
    const struct grammar *grammar)
{
	FILE *fh = stdin;
	char *buf = NULL;
	size_t bufsiz = 0;
	int error = 0;
	int lno = 0;

	for (;;) {
		ssize_t buflen;

		buflen = getline(&buf, &bufsiz, fh);
		if (buflen == -1) {
			if (feof(fh))
				break;
			warn("getline");
			error = 1;
			break;
		}
		error = variables_interpolate1(variables, grammar, buf, ++lno);
		if (error)
			break;
	}

	free(buf);
	return error;
}

static int
variables_interpolate1(struct variable_list *variables,
    const struct grammar *grammar, const char *str, int lno)
{
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
			return 1;
		}
		vs += 1;
		ve = strchr(vs, '}');
		if (ve == NULL) {
			log_warnx("/dev/stdin", lno,
			    "invalid substitution, expected '}'");
			return 1;
		}
		len = ve - vs;
		if (len == 0) {
			log_warnx("/dev/stdin", lno,
			    "invalid substitution, empty variable name");
			return 1;
		}

		va = variables_find(variables, grammar, vs, len);
		if (va == NULL) {
			log_warnx("/dev/stdin", lno,
			    "invalid substitution, unknown variable '%.*s'",
			    (int)len, vs);
			return 1;
		}

		printf("%.*s", (int)(p - str), str);

		switch (va->va_type) {
		case INTEGER:
			printf("%d", va->va_int);
			break;

		case STRING:
			printf("%s", va->va_str);
			break;

		case LIST: {
			const struct string *st;

			TAILQ_FOREACH(st, va->va_list, st_entry) {
				printf("%s%s", st->st_val,
				    TAILQ_LAST(va->va_list, string_list) == st
				    ? "" : " ");
			}
			break;
		}
		}

		str = &ve[1];
	}
	/* Output any remaining tail. */
	printf("%s", str);

	return 0;
}

static const struct variable *
variables_find(struct variable_list *variables, const struct grammar *grammar,
    const char *name, size_t namelen)
{
	static struct variable vadef;
	const struct variable *va;
	int i;

	TAILQ_FOREACH(va, variables, va_entry) {
		if (va->va_namelen == namelen &&
		    strncmp(va->va_name, name, namelen) == 0)
			return va;
	}

	/* Look for default value. */
	for (i = 0; grammar[i].gr_kw != NULL; i++) {
		void *val;

		if (strncmp(grammar[i].gr_kw, name, namelen) != 0 ||
		    (grammar[i].gr_flags & MANDATORY))
			continue;

		memset(&vadef, 0, sizeof(vadef));
		vadef.va_type = grammar[i].gr_type;
		val = grammar[i].gr_default;
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
variables_present(const struct variable_list *variables, const char *name)
{
	const struct variable *va;

	TAILQ_FOREACH(va, variables, va_entry) {
		if (strcmp(va->va_name, name) == 0)
			return 1;
	}
	return 0;
}

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

static int
parser_exec(struct parser *pr, struct variable_list *variables,
    const struct grammar *grammar)
{
	struct token tk;
	int error = 0;

	memset(&tk, 0, sizeof(tk));

	for (;;) {
		if (lexer_peek(&pr->pr_lx, TOKEN_EOF))
			break;
		if (!lexer_expect(&pr->pr_lx, TOKEN_KEYWORD, &tk)) {
			error = 1;
			break;
		}

		switch (parser_exec1(pr, variables, grammar, tk.tk_str)) {
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
parser_exec1(struct parser *pr, struct variable_list *variables,
    const struct grammar *grammar, const char *name)
{
	int i;

	for (i = 0; grammar[i].gr_kw != NULL; i++) {
		const struct grammar *gr = &grammar[i];
		void *val;
		int error = 0;

		if (strcmp(gr->gr_kw, name) != 0)
			continue;

		if (variables_present(variables, name)) {
			lexer_warnx(&pr->pr_lx,
			    "variable '%s' already defined", name);
			error = 1;
		}
		if (gr->gr_fn(pr, variables, &val) == 0)
			variables_append(variables, gr->gr_type, name, val);
		else
			error = 1;
		return error;
	}

	lexer_warnx(&pr->pr_lx, "unknown keyword '%s'", name);
	return -1;
}

static int
parser_boolean(struct parser *pr, struct variable_list *UNUSED(variables),
    void **val)
{
	struct token tk;

	if (!lexer_expect(&pr->pr_lx, TOKEN_BOOLEAN, &tk))
		return 1;
	*val = (void *)tk.tk_int;
	return 0;
}

static int
parser_string(struct parser *pr, struct variable_list *UNUSED(variables),
    void **val)
{
	struct token tk;

	if (!lexer_expect(&pr->pr_lx, TOKEN_STRING, &tk))
		return 1;
	*val = tk.tk_str;
	return 0;
}

static int
parser_integer(struct parser *pr, struct variable_list *UNUSED(variables),
    void **val)
{
	struct token tk;

	if (!lexer_expect(&pr->pr_lx, TOKEN_INTEGER, &tk))
		return 1;
	*val = (void *)tk.tk_int;
	return 0;
}

static int
parser_glob(struct parser *pr, struct variable_list *UNUSED(variables),
    void **val)
{
	glob_t g;
	struct token tk;
	struct string_list *strings = NULL;
	size_t i;
	int error;

	if (!lexer_expect(&pr->pr_lx, TOKEN_STRING, &tk))
		return 1;
	error = glob(tk.tk_str, GLOB_NOCHECK, NULL, &g);
	if (error) {
		lexer_warn(&pr->pr_lx, "glob: %d", error);
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
parser_dir(struct parser *pr, struct variable_list *UNUSED(variables),
    void **val)
{
	struct stat st;
	struct token tk;

	if (!lexer_expect(&pr->pr_lx, TOKEN_STRING, &tk))
		return 1;
	if (stat(tk.tk_str, &st) == -1) {
		lexer_warn(&pr->pr_lx, "%s", tk.tk_str);
		token_free(&tk);
		return 1;
	}
	if (!S_ISDIR(st.st_mode)) {
		lexer_warnx(&pr->pr_lx, "%s: is not a directory", tk.tk_str);
		token_free(&tk);
		return 1;
	}

	*val = tk.tk_str;
	return 0;
}

static int
parser_list(struct parser *pr, struct variable_list *UNUSED(variables),
    void **val)
{
	struct token tk;
	struct string_list *strings = NULL;

	if (!lexer_expect(&pr->pr_lx, TOKEN_LBRACE, &tk))
		return 1;
	strings = strings_alloc();
	for (;;) {
		if (lexer_peek(&pr->pr_lx, TOKEN_RBRACE))
			break;
		if (!lexer_expect(&pr->pr_lx, TOKEN_STRING, &tk))
			goto err;
		strings_append(strings, tk.tk_str);
		token_free(&tk);
	}
	if (!lexer_expect(&pr->pr_lx, TOKEN_RBRACE, &tk))
		goto err;

	*val = strings;
	return 0;

err:
	strings_free(strings);
	return 1;
}

static int
parser_user(struct parser *pr, struct variable_list *variables, void **val)
{
	char *user;

	if (parser_string(pr, variables, (void **)&user))
		return 1;
	if (getpwnam(user) == NULL) {
		lexer_warnx(&pr->pr_lx, "user '%s' not found", user);
		free(user);
		return 1;
	}

	*val = user;
	return 0;
}

static int
parser_regress(struct parser *pr, struct variable_list *variables, void **val)
{
	struct string_list *regress, *root, *skip;
	struct string *st;

	if (parser_list(pr, variables, (void **)&regress))
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
			lexer_warnx(&pr->pr_lx, "empty regress flags");
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
				lexer_warnx(&pr->pr_lx,
				    "unknown regress flag '%c'", *p);
			}
		}
	}

	variables_append(variables, LIST, "regress-root", root);
	variables_append(variables, LIST, "regress-skip", skip);

	*val = regress;
	return 0;
}

static struct string_list *
strings_alloc(void)
{
	struct string_list *strings;

	strings = malloc(sizeof(*strings));
	if (strings == NULL)
		err(1, NULL);
	TAILQ_INIT(strings);
	return strings;
}

static void
strings_free(struct string_list *strings)
{
	struct string *st;

	if (strings == NULL)
		return;

	while ((st = TAILQ_FIRST(strings)) != NULL) {
		TAILQ_REMOVE(strings, st, st_entry);
		free(st->st_val);
		free(st);
	}
	free(strings);
}

static void
strings_append(struct string_list *strings, char *val)
{
	struct string *st;

	st = malloc(sizeof(*st));
	if (st == NULL)
		err(1, NULL);
	st->st_val = strdup(val);
	if (st->st_val == NULL)
		err(1, NULL);
	TAILQ_INSERT_TAIL(strings, st, st_entry);
}
