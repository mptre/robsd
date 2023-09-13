#include "conf.h"

#include "config.h"

#include <sys/param.h>	/* MACHINE, MACHINE_ARCH */
#include <sys/stat.h>

#include <assert.h>
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

#include "libks/arithmetic.h"
#include "libks/buffer.h"
#include "libks/vector.h"

#include "alloc.h"
#include "if.h"
#include "interpolate.h"
#include "lexer.h"
#include "log.h"
#include "token.h"

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

struct parser_context {
	struct buffer	*pc_bf;
};

static void	parser_context_init(struct parser_context *);
static void	parser_context_reset(struct parser_context *);

static struct token	*config_lexer_read(struct lexer *, void *);
static const char	*token_serialize(const struct token *);

/*
 * variable --------------------------------------------------------------------
 */

struct variable {
	char			*va_name;
	size_t			 va_namelen;
	struct variable_value	 va_val;

	unsigned int		 va_flags;
#define VARIABLE_FLAG_DIRTY	0x00000001u
};

static void	variable_value_init(struct variable_value *,
    enum variable_type);
static void	variable_value_clear(struct variable_value *);
static void	variable_value_concat(struct variable_value *,
    struct variable_value *);

/*
 * grammar ---------------------------------------------------------------------
 */

struct grammar {
	const char		*gr_kw;
	enum variable_type	 gr_type;
	int			 (*gr_fn)(struct config *,
	    struct variable_value *);
	unsigned int		 gr_flags;
#define REQ	0x00000001u	/* required */
#define REP	0x00000002u	/* may be repeated */
#define PAT	0x00000004u	/* fnmatch(3) keyword fallback */
#define FUN	0x00000008u	/* default obtain through function call */

	union {
		const void	*ptr;
		struct variable	*(*fun)(struct config *, const char *);
	} gr_default;
};

static const struct grammar	*grammar_find(const struct grammar *,
    const char *);
static int			 grammar_equals(const struct grammar *,
    const char *, size_t);

/*
 * config ----------------------------------------------------------------------
 */

struct config {
	struct buffer		*cf_scratch;
	struct lexer		*cf_lx;
	const struct grammar	*cf_grammar;
	const char		*cf_path;
	struct {
		const char *const	*ptr;
		size_t			 len;
	} cf_steps;
	enum robsd_mode		 cf_mode;

	VECTOR(struct variable)	 cf_variables;

	/* Sentinel used for absent list variables during interpolation. */
	VECTOR(char *)		 cf_empty_list;
};

static int	config_parse1(struct config *);
static int	config_parse_keyword(struct config *, struct token *);
static int	config_validate(const struct config *);
static int	config_parse_boolean(struct config *, struct variable_value *);
static int	config_parse_string(struct config *, struct variable_value *);
static int	config_parse_integer(struct config *, struct variable_value *);
static int	config_parse_glob(struct config *, struct variable_value *);
static int	config_parse_list(struct config *, struct variable_value *);
static int	config_parse_user(struct config *, struct variable_value *);
static int	config_parse_regress(struct config *, struct variable_value *);
static int	config_parse_regress_env(struct config *,
    struct variable_value *);
static int	config_parse_directory(struct config *,
    struct variable_value *);

static struct variable	*config_default_build_dir(struct config *,
    const char *);
static struct variable	*config_default_inet4(struct config *, const char *);
static struct variable	*config_default_inet6(struct config *, const char *);

static struct variable	*config_append(struct config *, const char *,
    const struct variable_value *, unsigned int);
static struct variable	*config_append_string(struct config *,
    const char *, const char *);
static int		 config_present(const struct config *,
    const char *);
static struct variable	*config_find_or_create_list(struct config *,
    const char *);

static const char	*regressname(struct buffer *, const char *,
    const char *);

static const void *novalue;

#define COMMON_DEFAULTS							\
	{ "arch",	STRING,	NULL,	0,	{ MACHINE_ARCH } },	\
	{ "builddir",	STRING,	NULL,	FUN,	{ .fun = config_default_build_dir } },\
	{ "inet",	STRING,	NULL,	FUN,	{ .fun = config_default_inet4 } },\
	{ "inet6",	STRING,	NULL,	FUN,	{ .fun = config_default_inet6 } },\
	{ "keep-dir",	STRING,	NULL,	0,	{ "${robsddir}/attic" } },\
	{ "machine",	STRING,	NULL,	0,	{ MACHINE } }

static const struct grammar robsd[] = {
	{ "robsddir",		DIRECTORY,	config_parse_directory,	REQ,	{ NULL } },
	{ "builduser",		STRING,		config_parse_user,	0,	{ "build" } },
	{ "destdir",		DIRECTORY,	config_parse_directory,	REQ,	{ NULL } },
	{ "hook",		LIST,		config_parse_list,	0,	{ NULL } },
	{ "keep",		INTEGER,	config_parse_integer,	0,	{ NULL } },
	{ "kernel",		STRING,		config_parse_string,	0,	{ "GENERIC.MP" } },
	{ "reboot",		INTEGER,	config_parse_boolean,	0,	{ NULL } },
	{ "skip",		LIST,		config_parse_list,	0,	{ NULL } },
	{ "bsd-diff",		LIST,		config_parse_glob,	0,	{ NULL } },
	{ "bsd-objdir",		DIRECTORY,	config_parse_directory,	0,	{ "/usr/obj" } },
	{ "bsd-reldir",		STRING,		NULL,			0,	{ "${builddir}/rel" } },
	{ "bsd-srcdir",		DIRECTORY,	config_parse_directory,	0,	{ "/usr/src" } },
	{ "cvs-root",		STRING,		config_parse_string,	0,	{ NULL } },
	{ "cvs-user",		STRING,		config_parse_user,	0,	{ NULL } },
	{ "distrib-host",	STRING,		config_parse_string,	0,	{ NULL } },
	{ "distrib-path",	STRING,		config_parse_string,	0,	{ NULL } },
	{ "distrib-signify",	STRING,		config_parse_string,	0,	{ NULL } },
	{ "distrib-user",	STRING,		config_parse_user,	0,	{ NULL } },
	{ "x11-diff",		LIST,		config_parse_glob,	0,	{ NULL } },
	{ "x11-objdir",		DIRECTORY,	config_parse_directory,	0,	{ "/usr/xobj" } },
	{ "x11-reldir",		STRING,		NULL,			0,	{ "${builddir}/relx" } },
	{ "x11-srcdir",		DIRECTORY,	config_parse_directory,	0,	{ "/usr/xenocara" } },

	COMMON_DEFAULTS,
	{ NULL, 0, NULL, 0, { NULL } },
};

static const char *robsd_steps[] = {
	"env",
	"cvs",
	"patch",
	"kernel",
	"reboot",
	"env",
	"base",
	"release",
	"checkflist",
	"xbase",
	"xrelease",
	"image",
	"hash",
	"revert",
	"distrib",
	"dmesg",
	"end",
};

static const struct grammar robsd_cross[] = {
	{ "robsddir",	DIRECTORY,	config_parse_directory,	REQ,	{ NULL } },
	{ "builduser",	STRING,		config_parse_user,	0,	{ "build" } },
	{ "crossdir",	STRING,		config_parse_string,	REQ,	{ NULL } },
	{ "keep",	INTEGER,	config_parse_integer,	0,	{ NULL } },
	{ "skip",	LIST,		config_parse_list,	0,	{ NULL } },
	{ "bsd-srcdir",	DIRECTORY,	config_parse_directory,	0,	{ "/usr/src" } },

	COMMON_DEFAULTS,
	{ NULL, 0, NULL, 0, { NULL } },
};

static const char *robsd_cross_steps[] = {
	"env",
	"dirs",
	"tools",
	"distrib",
	"dmesg",
	"end",
};

static const struct grammar robsd_ports[] = {
	{ "robsddir",		DIRECTORY,	config_parse_directory,	REQ,	{ NULL } },
	{ "chroot",		STRING,		config_parse_string,	REQ,	{ NULL } },
	{ "hook",		LIST,		config_parse_list,	0,	{ NULL } },
	{ "keep",		INTEGER,	config_parse_integer,	0,	{ NULL } },
	{ "skip",		LIST,		config_parse_list,	0,	{ NULL } },
	{ "cvs-root",		STRING,		config_parse_string,	0,	{ NULL } },
	{ "cvs-user",		STRING,		config_parse_user,	0,	{ NULL } },
	{ "distrib-host",	STRING,		config_parse_string,	0,	{ NULL } },
	{ "distrib-path",	STRING,		config_parse_string,	0,	{ NULL } },
	{ "distrib-signify",	STRING,		config_parse_string,	0,	{ NULL } },
	{ "distrib-user",	STRING,		config_parse_user,	0,	{ NULL } },
	{ "ports",		LIST,		config_parse_list,	REQ,	{ NULL } },
	{ "ports-diff",		LIST,		config_parse_glob,	0,	{ NULL } },
	{ "ports-dir",		STRING,		config_parse_string,	0,	{ "/usr/ports" } },
	{ "ports-user",		STRING,		config_parse_user,	REQ,	{ NULL } },

	COMMON_DEFAULTS,
	{ NULL, 0, NULL, 0, { NULL } },
};

static const char *robsd_ports_steps[] = {
	"env",
	"cvs",
	"clean",
	"proot",
	"patch",
	"dpb",
	"distrib",
	"revert",
	"dmesg",
	"end",
};

static const struct grammar robsd_regress[] = {
	{ "robsddir",		DIRECTORY,	config_parse_directory,		REQ,		{ NULL } },
	{ "hook",		LIST,		config_parse_list,		0,		{ NULL } },
	{ "keep",		INTEGER,	config_parse_integer,		0,		{ NULL } },
	{ "rdonly",		INTEGER,	config_parse_boolean,		0,		{ NULL } },
	{ "sudo",		STRING,		config_parse_string,		0,		{ "doas -n" } },
	{ "bsd-diff",		LIST,		config_parse_glob,		0,		{ NULL } },
	{ "bsd-srcdir",		DIRECTORY,	config_parse_directory,		0,		{ "/usr/src" } },
	{ "cvs-root",		STRING,		config_parse_string,		0,		{ NULL } },
	{ "cvs-user",		STRING,		config_parse_user,		0,		{ NULL } },
	{ "regress",		LIST,		config_parse_regress,		REQ|REP,	{ NULL } },
	{ "regress-env",	LIST,		config_parse_regress_env,	REP,		{ NULL } },
	{ "regress-user",	STRING,		config_parse_user,		0,		{ "build" } },
	{ "regress-*-env",	STRING,		NULL,				PAT,		{ "${regress-env}" } },
	{ "regress-*-target",	STRING,		NULL,				PAT,		{ "regress" } },

	COMMON_DEFAULTS,
	{ NULL, 0, NULL, 0, { NULL } },
};

static const char *robsd_regress_steps[] = {
	"env",
	"pkg-add",
	"cvs",
	"patch",
	"obj",
	"mount",
	NULL,		/* ${regress} */
	"umount",
	"revert",
	"pkg-del",
	"dmesg",
	"end",
};

struct config *
config_alloc(const char *mode, const char *path)
{
	struct config *cf;
	const char *defaultpath = NULL;
	enum robsd_mode m;

	if (robsd_mode_parse(mode, &m)) {
		warnx("unknown mode '%s'", mode);
		return NULL;
	}

	cf = ecalloc(1, sizeof(*cf));
	cf->cf_scratch = buffer_alloc(128);
	if (cf->cf_scratch == NULL)
		err(1, NULL);
	cf->cf_path = path;
	cf->cf_mode = m;
	if (VECTOR_INIT(cf->cf_variables))
		err(1, NULL);
	if (VECTOR_INIT(cf->cf_empty_list))
		err(1, NULL);

	switch (cf->cf_mode) {
	case ROBSD:
		defaultpath = "/etc/robsd.conf";
		cf->cf_grammar = robsd;
		cf->cf_steps.ptr = robsd_steps;
		cf->cf_steps.len = sizeof(robsd_steps) / sizeof(robsd_steps[0]);
		break;
	case ROBSD_CROSS:
		defaultpath = "/etc/robsd-cross.conf";
		cf->cf_grammar = robsd_cross;
		cf->cf_steps.ptr = robsd_cross_steps;
		cf->cf_steps.len = sizeof(robsd_cross_steps) /
		    sizeof(robsd_cross_steps[0]);
		break;
	case ROBSD_PORTS:
		defaultpath = "/etc/robsd-ports.conf";
		cf->cf_grammar = robsd_ports;
		cf->cf_steps.ptr = robsd_ports_steps;
		cf->cf_steps.len = sizeof(robsd_ports_steps) /
		    sizeof(robsd_ports_steps[0]);
		break;
	case ROBSD_REGRESS:
		defaultpath = "/etc/robsd-regress.conf";
		cf->cf_grammar = robsd_regress;
		cf->cf_steps.ptr = robsd_regress_steps;
		cf->cf_steps.len = sizeof(robsd_regress_steps) /
		    sizeof(robsd_regress_steps[0]);
		break;
	}
	if (cf->cf_path == NULL)
		cf->cf_path = defaultpath;

	return cf;
}

void
config_free(struct config *cf)
{
	if (cf == NULL)
		return;

	while (!VECTOR_EMPTY(cf->cf_variables)) {
		struct variable *va;

		va = VECTOR_POP(cf->cf_variables);
		variable_value_clear(&va->va_val);
		if (va->va_flags & VARIABLE_FLAG_DIRTY)
			free((void *)va->va_val.ptr);
		free(va->va_name);
	}
	VECTOR_FREE(cf->cf_variables);

	buffer_free(cf->cf_scratch);
	lexer_free(cf->cf_lx);
	VECTOR_FREE(cf->cf_empty_list);
	free(cf);
}

int
config_parse(struct config *cf)
{
	struct parser_context pc;
	int error;

	parser_context_init(&pc);
	cf->cf_lx = lexer_alloc(&(struct lexer_arg){
	    .path = cf->cf_path,
	    .callbacks = {
		.read		= config_lexer_read,
		.serialize	= token_serialize,
		.arg		= &pc,
	    },
	});
	if (cf->cf_lx == NULL) {
		error = 1;
		goto out;
	}
	error = config_parse1(cf);

out:
	parser_context_reset(&pc);
	return error;
}

int
config_append_var(struct config *cf, const char *str)
{
	char *name, *val;
	size_t namelen;
	int error = 0;

	val = strchr(str, '=');
	if (val == NULL) {
		warnx("missing variable separator in '%s'", str);
		return 1;
	}
	namelen = (size_t)(val - str);
	name = estrndup(str, namelen);
	val++;	/* consume '=' */
	if (config_append_string(cf, name, val) == NULL) {
		warnx("variable '%s' cannot be defined", name);
		error = 1;
	}
	free(name);
	return error;
}

static struct variable *
config_append_string(struct config *cf, const char *name, const char *str)
{
	struct variable_value val;

	if (grammar_find(cf->cf_grammar, name))
		return NULL;

	variable_value_init(&val, STRING);
	val.str = estrdup(str);
	return config_append(cf, name, &val, VARIABLE_FLAG_DIRTY);
}

static struct variable *
config_find_or_create_list(struct config *cf, const char *name)
{
	if (!config_present(cf, name)) {
		struct variable_value val;

		variable_value_init(&val, LIST);
		config_append(cf, name, &val, 0);
	}
	return config_find(cf, name);
}

struct variable *
config_find(struct config *cf, const char *name)
{
	static struct variable vadef;
	struct variable *va;
	size_t i, namelen;

	namelen = strlen(name);
	for (i = 0; i < VECTOR_LENGTH(cf->cf_variables); i++) {
		va = &cf->cf_variables[i];
		if (va->va_namelen == namelen &&
		    strncmp(va->va_name, name, namelen) == 0)
			return va;
	}

	/* Look for default value. */
	for (i = 0; cf->cf_grammar[i].gr_kw != NULL; i++) {
		const struct grammar *gr = &cf->cf_grammar[i];
		const void *val;

		if (gr->gr_flags & REQ)
			continue;

		if (!grammar_equals(gr, name, namelen))
			continue;

		if (gr->gr_flags & FUN) {
			char *fname;

			fname = estrndup(name, namelen);
			va = gr->gr_default.fun(cf, fname);
			free(fname);
			return va;
		}

		memset(&vadef, 0, sizeof(vadef));
		vadef.va_val.type = gr->gr_type;
		val = gr->gr_default.ptr;
		switch (vadef.va_val.type) {
		case INTEGER:
			vadef.va_val.integer = 0;
			break;

		case STRING:
		case DIRECTORY: {
			vadef.va_val.str = (char *)(val == NULL ? "" : val);
			break;
		}

		case LIST:
			vadef.va_val.list = cf->cf_empty_list;
			break;
		}
		return &vadef;
	}

	return NULL;
}

int
config_interpolate(struct config *cf)
{
	char *str;

	str = interpolate_file("/dev/stdin", &(struct interpolate_arg){
	    .lookup	= config_interpolate_lookup,
	    .arg	= cf,
	});
	if (str == NULL)
		return 1;
	printf("%s", str);
	free(str);
	return 0;
}

char *
config_interpolate_str(struct config *cf, const char *str)
{
	return interpolate_str(str, &(struct interpolate_arg){
	    .lookup	= config_interpolate_lookup,
	    .arg	= cf,
	});
}

char *
config_interpolate_lookup(const char *name, void *arg)
{
	struct config *cf = (struct config *)arg;
	struct buffer *bf;
	const struct variable *va;
	char *str;

	va = config_find(cf, name);
	if (va == NULL)
		return NULL;

	bf = buffer_alloc(128);
	if (bf == NULL)
		err(1, NULL);
	switch (va->va_val.type) {
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
	str = buffer_str(bf);
	buffer_free(bf);
	return str;
}

enum robsd_mode
config_get_mode(const struct config *cf)
{
	return cf->cf_mode;
}

static const char **
config_regress_get_steps(struct config *cf)
{
	VECTOR(const char *) steps;
	VECTOR(char *) regress;
	size_t i = 0;
	size_t nregress, r, s;

	regress = config_find_value(cf, "regress", list);
	nregress = VECTOR_LENGTH(regress);

	if (VECTOR_INIT(steps))
		err(1, NULL);
	if (VECTOR_RESERVE(steps, cf->cf_steps.len + nregress))
		err(1, NULL);

	for (s = 0; s < cf->cf_steps.len; s++) {
		if (cf->cf_steps.ptr[s] == NULL)
			break;

		if (VECTOR_ALLOC(steps) == NULL)
			err(1, NULL);
		steps[i++] = cf->cf_steps.ptr[s];
	}

	for (r = 0; r < nregress; r++) {
		if (VECTOR_ALLOC(steps) == NULL)
			err(1, NULL);
		steps[i++] = regress[r];
	}

	for (s++; s < cf->cf_steps.len; s++) {
		if (VECTOR_ALLOC(steps) == NULL)
			err(1, NULL);
		steps[i++] = cf->cf_steps.ptr[s];
	}

	return steps;
}

/*
 * Returns a vector including all steps. The caller is responsible for freeing
 * the vector.
 */
const char **
config_get_steps(struct config *cf)
{
	VECTOR(const char *) steps;
	size_t i;

	if (cf->cf_mode == ROBSD_REGRESS)
		return config_regress_get_steps(cf);

	if (VECTOR_INIT(steps))
		err(1, NULL);
	if (VECTOR_RESERVE(steps, cf->cf_steps.len))
		err(1, NULL);

	for (i = 0; i < cf->cf_steps.len; i++) {
		if (VECTOR_ALLOC(steps) == NULL)
			err(1, NULL);
		steps[i] = cf->cf_steps.ptr[i];
	}

	return steps;
}

const struct variable_value *
variable_get_value(const struct variable *va)
{
	return &va->va_val;
}

static void
parser_context_init(struct parser_context *pc)
{
	pc->pc_bf = buffer_alloc(512);
	if (pc->pc_bf == NULL)
		err(1, NULL);
}

static void
parser_context_reset(struct parser_context *pc)
{
	buffer_free(pc->pc_bf);
}

static struct token *
config_lexer_read(struct lexer *lx, void *arg)
{
	struct lexer_state s;
	struct parser_context *pc = (struct parser_context *)arg;
	struct buffer *bf = pc->pc_bf;
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
		if (strcmp("env", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_ENV);
		if (strcmp("obj", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_OBJ);
		if (strcmp("packages", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_PACKAGES);
		if (strcmp("quiet", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_QUIET);
		if (strcmp("root", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_ROOT);
		if (strcmp("target", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_TARGET);

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

			if (i32_mul_overflow(val, 10, &val) ||
			    i32_add_overflow(val, x, &val))
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
	return "UNKNOWN";
}

static void
variable_value_init(struct variable_value *val, enum variable_type type)
{
	memset(val, 0, sizeof(*val));
	val->type = type;

	switch (type) {
	case LIST:
		if (VECTOR_INIT(val->list))
			err(1, NULL);
		break;
	case INTEGER:
	case STRING:
	case DIRECTORY:
		break;
	}
}

static void
variable_value_clear(struct variable_value *val)
{
	switch (val->type) {
	case LIST: {
		while (!VECTOR_EMPTY(val->list)) {
			char **str;

			str = VECTOR_POP(val->list);
			free(*str);
		}
		VECTOR_FREE(val->list);
		break;
	}

	case INTEGER:
	case STRING:
	case DIRECTORY:
		break;
	}
}

static void
variable_value_concat(struct variable_value *dst, struct variable_value *src)
{
	size_t i;

	assert(dst->type == LIST && src->type == LIST);

	for (i = 0; i < VECTOR_LENGTH(src->list); i++) {
		char **str;

		str = VECTOR_ALLOC(dst->list);
		if (str == NULL)
			err(1, NULL);
		*str = src->list[i];
	}
	VECTOR_FREE(src->list);
}

static const struct grammar *
grammar_find(const struct grammar *grammar, const char *name)
{
	int i;

	for (i = 0; grammar[i].gr_kw != NULL; i++) {
		const struct grammar *gr = &grammar[i];

		if (gr->gr_fn != NULL && strcmp(gr->gr_kw, name) == 0)
			return gr;
	}
	return NULL;
}

static int
grammar_equals(const struct grammar *gr, const char *str, size_t len)
{
	size_t kwlen;

	kwlen = strlen(gr->gr_kw);
	if (kwlen == len && strncmp(gr->gr_kw, str, len) == 0)
		return 1;
	if (gr->gr_flags & PAT) {
		char *buf;
		int match;

		buf = estrndup(str, len);
		match = fnmatch(gr->gr_kw, buf, 0) == 0;
		free(buf);
		return match;
	}
	return 0;
}

static int
config_parse1(struct config *cf)
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

		switch (config_parse_keyword(cf, tk)) {
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
config_parse_keyword(struct config *cf, struct token *tk)
{
	const struct grammar *gr;
	struct variable_value val;
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
	assert(gr->gr_fn != NULL);
	if (gr->gr_fn(cf, &val) == 0) {
		if (val.ptr != novalue)
			config_append(cf, tk->tk_str, &val, 0);
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

		if ((gr->gr_flags & REQ) && !config_present(cf, str)) {
			log_warnx(cf->cf_path, 0,
			    "mandatory variable '%s' missing", str);
			error = 1;
		}
	}

	return error;
}

static int
config_parse_boolean(struct config *cf, struct variable_value *val)
{
	struct token *tk;

	if (!lexer_expect(cf->cf_lx, TOKEN_BOOLEAN, &tk))
		return 1;
	variable_value_init(val, INTEGER);
	val->integer = tk->tk_int;
	return 0;
}

static int
config_parse_string(struct config *cf, struct variable_value *val)
{
	struct token *tk;

	if (!lexer_expect(cf->cf_lx, TOKEN_STRING, &tk))
		return 1;
	variable_value_init(val, STRING);
	val->str = tk->tk_str;
	return 0;
}

static int
config_parse_integer(struct config *cf, struct variable_value *val)
{
	struct token *tk;

	if (!lexer_expect(cf->cf_lx, TOKEN_INTEGER, &tk))
		return 1;
	variable_value_init(val, INTEGER);
	val->integer = tk->tk_int;
	return 0;
}

static int
config_parse_glob(struct config *cf, struct variable_value *val)
{
	glob_t g;
	struct token *tk;
	size_t i;
	int error;

	if (!lexer_expect(cf->cf_lx, TOKEN_STRING, &tk))
		return 1;

	variable_value_init(val, LIST);

	error = glob(tk->tk_str, 0, NULL, &g);
	if (error) {
		if (error == GLOB_NOMATCH)
			return 0;

		lexer_warn(cf->cf_lx, tk->tk_lno, "glob: %d", error);
		return error;
	}

	for (i = 0; i < g.gl_pathc; i++) {
		char **dst;

		dst = VECTOR_ALLOC(val->list);
		if (dst == NULL)
			err(1, NULL);
		*dst = estrdup(g.gl_pathv[i]);
	}

	globfree(&g);
	return 0;
}

static int
config_parse_list(struct config *cf, struct variable_value *val)
{
	struct token *tk;

	if (!lexer_expect(cf->cf_lx, TOKEN_LBRACE, &tk))
		return 1;
	variable_value_init(val, LIST);
	for (;;) {
		char **dst;

		if (lexer_peek(cf->cf_lx, TOKEN_RBRACE))
			break;
		if (!lexer_expect(cf->cf_lx, TOKEN_STRING, &tk))
			goto err;
		dst = VECTOR_ALLOC(val->list);
		if (dst == NULL)
			err(1, NULL);
		*dst = estrdup(tk->tk_str);
	}
	if (!lexer_expect(cf->cf_lx, TOKEN_RBRACE, &tk))
		goto err;

	return 0;

err:
	variable_value_clear(val);
	return 1;
}

static int
config_parse_user(struct config *cf, struct variable_value *val)
{
	struct token *tk;
	const char *user;

	if (!lexer_expect(cf->cf_lx, TOKEN_STRING, &tk))
		return 1;
	variable_value_init(val, STRING);
	user = val->str = tk->tk_str;
	if (getpwnam(user) == NULL) {
		lexer_warnx(cf->cf_lx, tk->tk_lno, "user '%s' not found",
		    user);
		return 1;
	}
	return 0;
}

static int
config_parse_regress(struct config *cf, struct variable_value *val)
{
	struct buffer *bf = cf->cf_scratch;
	struct lexer *lx = cf->cf_lx;
	struct token *tk;
	struct variable *regress;
	const char *path;
	char **dst;

	if (!lexer_expect(lx, TOKEN_STRING, &tk))
		return 1;
	path = tk->tk_str;

	for (;;) {
		const char *name;

		if (lexer_if(lx, TOKEN_ENV, &tk)) {
			struct variable_value defval, newval;

			if (config_parse_list(cf, &newval))
				return 1;

			/* Add default enviroment. */
			name = regressname(bf, path, "env");
			variable_value_init(&defval, LIST);
			dst = VECTOR_ALLOC(defval.list);
			if (dst == NULL)
				err(1, NULL);
			*dst = estrdup("${regress-env}");
			variable_value_concat(&defval, &newval);
			config_append(cf, name, &defval, 0);
		} else if (lexer_if(lx, TOKEN_OBJ, &tk)) {
			struct variable_value newval;
			struct variable *obj;

			if (config_parse_list(cf, &newval))
				return 1;
			obj = config_find_or_create_list(cf, "regress-obj");
			variable_value_concat(&obj->va_val, &newval);
		} else if (lexer_if(lx, TOKEN_PACKAGES, &tk)) {
			struct variable_value newval;
			struct variable *packages;

			if (config_parse_list(cf, &newval))
				return 1;
			packages = config_find_or_create_list(cf,
			    "regress-packages");
			variable_value_concat(&packages->va_val, &newval);
		} else if (lexer_if(lx, TOKEN_QUIET, &tk)) {
			struct variable_value newval;

			name = regressname(bf, path, "quiet");
			variable_value_init(&newval, INTEGER);
			newval.integer = 1;
			config_append(cf, name, &newval, 0);
		} else if (lexer_if(lx, TOKEN_ROOT, &tk)) {
			struct variable_value newval;

			name = regressname(bf, path, "root");
			variable_value_init(&newval, INTEGER);
			newval.integer = 1;
			config_append(cf, name, &newval, 0);
		} else if (lexer_if(lx, TOKEN_TARGET, &tk)) {
			struct variable_value newval;

			if (config_parse_string(cf, &newval))
				return 1;
			name = regressname(bf, path, "target");
			config_append(cf, name, &newval, 0);
		} else {
			break;
		}
	}

	regress = config_find_or_create_list(cf, "regress");
	dst = VECTOR_ALLOC(regress->va_val.list);
	if (dst == NULL)
		err(1, NULL);
	*dst = estrdup(path);
	val->ptr = novalue;
	return 0;
}

static int
config_parse_regress_env(struct config *cf, struct variable_value *val)
{
	struct variable *env;

	if (config_parse_list(cf, val))
		return 1;

	if (!config_present(cf, "regress-env")) {
		struct variable_value def;

		variable_value_init(&def, LIST);
		config_append(cf, "regress-env", &def, 0);
	}
	env = config_find(cf, "regress-env");
	variable_value_concat(&env->va_val, val);
	val->ptr = novalue;
	return 0;
}

static int
config_parse_directory(struct config *cf, struct variable_value *val)
{
	struct stat st;
	struct token *tk;
	const char *dir;
	char *path;
	int error = 0;

	if (!lexer_expect(cf->cf_lx, TOKEN_STRING, &tk))
		return 1;
	variable_value_init(val, STRING);
	dir = val->str = tk->tk_str;
	/* Empty string error already reported by the lexer. */
	if (dir[0] == '\0')
		return 1;

	path = interpolate_str(dir, &(struct interpolate_arg){
	    .lookup	= config_interpolate_lookup,
	    .arg	= cf,
	    .lno	= tk->tk_lno,
	});
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

static struct variable *
config_default_build_dir(struct config *cf, const char *name)
{
	struct buffer *bf = NULL;
	struct variable *va = NULL;
	char *nl, *path;
	int fd = -1;

	path = interpolate_str("${robsddir}/.running",
	    &(struct interpolate_arg){
		.lookup	= config_interpolate_lookup,
		.arg	= cf,
	});
	if (path == NULL)
		return NULL;

	/*
	 * The lock file is only expected to be present while robsd is running.
	 * Therefore do not treat failures as fatal.
	 */
	fd = open(path, O_RDONLY | O_CLOEXEC);
	if (fd == -1)
		goto out;
	bf = buffer_read_fd(fd);
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
	buffer_free(bf);
	free(path);
	return va;
}

static struct variable *
config_default_inet4(struct config *cf, const char *name)
{
	struct variable_value val;
	char *addr;

	addr = if_group_addr("egress", 4);
	if (addr == NULL)
		addr = estrdup("");
	variable_value_init(&val, STRING);
	val.str = addr;
	return config_append(cf, name, &val, VARIABLE_FLAG_DIRTY);
}

static struct variable *
config_default_inet6(struct config *cf, const char *name)
{
	struct variable_value val;
	char *addr;

	addr = if_group_addr("egress", 6);
	if (addr == NULL)
		addr = estrdup("");
	variable_value_init(&val, STRING);
	val.str = addr;
	return config_append(cf, name, &val, VARIABLE_FLAG_DIRTY);
}

static struct variable *
config_append(struct config *cf, const char *name,
    const struct variable_value *val, unsigned int flags)
{
	struct variable *va;

	va = VECTOR_CALLOC(cf->cf_variables);
	if (va == NULL)
		err(1, NULL);
	va->va_flags = flags;
	va->va_name = estrdup(name);
	va->va_namelen = strlen(name);
	va->va_val = *val;
	return va;
}

static int
config_present(const struct config *cf, const char *name)
{
	size_t i;

	for (i = 0; i < VECTOR_LENGTH(cf->cf_variables); i++) {
		const struct variable *va = &cf->cf_variables[i];

		if (strcmp(va->va_name, name) == 0)
			return 1;
	}
	return 0;
}

static const char *
regressname(struct buffer *bf, const char *path, const char *suffix)
{
	buffer_reset(bf);
	buffer_printf(bf, "regress-%s-%s", path, suffix);
	buffer_putc(bf, '\0');
	return buffer_get_ptr(bf);
}
