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

#include "libks/arena-buffer.h"
#include "libks/arena.h"
#include "libks/arithmetic.h"
#include "libks/buffer.h"
#include "libks/compiler.h"
#include "libks/vector.h"

#include "alloc.h"
#include "if.h"
#include "interpolate.h"
#include "lexer.h"
#include "log.h"
#include "token.h"

/*
 * Bounds for rdomain, favor something large enough to not conflict with
 * existing ones.
 */
#define RDOMAIN_MIN	11
#define RDOMAIN_MAX	256

enum token_type {
	/* sentinels */
	TOKEN_UNKNOWN,

	/* literals */
	TOKEN_LBRACE,
	TOKEN_RBRACE,

	/* keywords */
	TOKEN_KEYWORD,
	TOKEN_ENV,
	TOKEN_NO_PARALLEL,
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

static struct token	*config_lexer_read(struct lexer *, void *);
static const char	*token_serialize(const struct token *);

/*
 * variable --------------------------------------------------------------------
 */

struct variable {
	char			*va_name;
	size_t			 va_namelen;
	struct variable_value	 va_val;
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
#define EARLY	0x00000010u	/* interpolate early */

	union {
		const void	*ptr;
		struct variable	*(*fun)(struct config *, const char *);
		int		 i32;
#define D_FUN(x)	.fun = (x)
#define D_I32(x)	.i32 = (x)
	} gr_default;
};

static const struct grammar	*config_find_grammar_for_keyword(
    const struct config *, const char *);
static const struct grammar	*config_find_grammar_for_interpolation(
    const struct config *, const char *);
static int			 grammar_equals(const struct grammar *,
    const char *);

/*
 * config ----------------------------------------------------------------------
 */

struct config {
	struct arena_scope		*eternal;
	struct arena			*scratch;
	struct lexer			*lx;
	const char			*path;

	VECTOR(const struct grammar *)	 grammar;

	struct {
		const char *const	*ptr;
		size_t			 len;
	} steps;

	struct {
		int	early;
		int	rdomain;
	} interpolate;

	VECTOR(struct variable)		 variables;

	/* Sentinel used for absent list variables during interpolation. */
	VECTOR(char *)			 empty_list;

	enum robsd_mode			 mode;
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
static int	config_parse_regress_option_env(struct config *, const char *);
static int	config_parse_regress_env(struct config *,
    struct variable_value *);
static int	config_parse_directory(struct config *,
    struct variable_value *);

static struct variable	*config_default_build_dir(struct config *,
    const char *);
static struct variable	*config_default_exec_dir(struct config *, const char *);
static struct variable	*config_default_inet4(struct config *, const char *);
static struct variable	*config_default_inet6(struct config *, const char *);
static struct variable	*config_default_rdomain(struct config *, const char *);

static struct variable	*config_append(struct config *, const char *,
    const struct variable_value *);
static struct variable	*config_append_string(struct config *,
    const char *, const char *);
static int		 config_present(const struct config *,
    const char *);
static struct variable	*config_find(struct config *, const char *);
static struct variable	*config_find_or_create_list(struct config *,
    const char *);

static const char	*config_interpolate_early(struct config *,
    const char *);

static const char	*regressname(const char *, const char *,
    struct arena_scope *);

static const void *novalue;

/*
 * Common configuration shared among all robsd modes. Most of them are only
 * accessible during interpolation.
 */
static const struct grammar common_grammar[] = {
	{ "arch",	STRING,	NULL,	0,	{ MACHINE_ARCH } },
	{ "builddir",	STRING,	NULL,	FUN,	{ D_FUN(config_default_build_dir) } },
	{ "exec-dir",	STRING,	NULL,	FUN,	{ D_FUN(config_default_exec_dir) } },
	{ "inet",	STRING,	NULL,	FUN,	{ D_FUN(config_default_inet4) } },
	{ "inet6",	STRING,	NULL,	FUN,	{ D_FUN(config_default_inet6) } },
	{ "keep-dir",	STRING,	NULL,	0,	{ "${robsddir}/attic" } },
	{ "machine",	STRING,	NULL,	0,	{ MACHINE } }
};

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
	{ "rdomain",		INTEGER,	NULL,				FUN|EARLY,	{ D_FUN(config_default_rdomain) } },
	{ "regress",		LIST,		config_parse_regress,		REQ|REP,	{ NULL } },
	{ "regress-env",	LIST,		config_parse_regress_env,	REP,		{ NULL } },
	{ "regress-user",	STRING,		config_parse_user,		0,		{ "build" } },
	{ "regress-*-env",	STRING,		NULL,				PAT|EARLY,	{ "${regress-env}" } },
	{ "regress-*-target",	STRING,		NULL,				PAT,		{ "regress" } },
	{ "regress-*-parallel",	INTEGER,	NULL,				PAT,		{ D_I32(1) } },
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
config_alloc(const char *mode, const char *path, struct arena_scope *eternal,
    struct arena *scratch)
{
	const struct grammar *grammar;
	struct config *cf;
	const char *defaultpath = NULL;
	size_t common_grammar_len = sizeof(common_grammar) /
	    sizeof(common_grammar[0]);
	size_t grammar_len = 0;
	size_t i;
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
	if (VECTOR_INIT(cf->grammar))
		err(1, NULL);
	if (VECTOR_INIT(cf->variables))
		err(1, NULL);
	if (VECTOR_INIT(cf->empty_list))
		err(1, NULL);
	cf->interpolate.rdomain = RDOMAIN_MIN;

	switch (cf->mode) {
	case ROBSD:
		defaultpath = "/etc/robsd.conf";
		grammar = robsd;
		grammar_len = sizeof(robsd) / sizeof(robsd[0]);
		cf->steps.ptr = robsd_steps;
		cf->steps.len = sizeof(robsd_steps) / sizeof(robsd_steps[0]);
		break;
	case ROBSD_CROSS:
		defaultpath = "/etc/robsd-cross.conf";
		grammar = robsd_cross;
		grammar_len = sizeof(robsd_cross) / sizeof(robsd_cross[0]);
		cf->steps.ptr = robsd_cross_steps;
		cf->steps.len = sizeof(robsd_cross_steps) /
		    sizeof(robsd_cross_steps[0]);
		break;
	case ROBSD_PORTS:
		defaultpath = "/etc/robsd-ports.conf";
		grammar = robsd_ports;
		grammar_len = sizeof(robsd_ports) / sizeof(robsd_ports[0]);
		cf->steps.ptr = robsd_ports_steps;
		cf->steps.len = sizeof(robsd_ports_steps) /
		    sizeof(robsd_ports_steps[0]);
		break;
	case ROBSD_REGRESS:
		defaultpath = "/etc/robsd-regress.conf";
		grammar = robsd_regress;
		grammar_len = sizeof(robsd_regress) / sizeof(robsd_regress[0]);
		cf->steps.ptr = robsd_regress_steps;
		cf->steps.len = sizeof(robsd_regress_steps) /
		    sizeof(robsd_regress_steps[0]);
		break;
	}
	if (cf->path == NULL)
		cf->path = defaultpath;

	if (VECTOR_RESERVE(cf->grammar, grammar_len + common_grammar_len))
		err(1, NULL);
	for (i = 0; i < grammar_len; i++) {
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

	return cf;
}

void
config_free(struct config *cf)
{
	if (cf == NULL)
		return;

	VECTOR_FREE(cf->grammar);

	while (!VECTOR_EMPTY(cf->variables)) {
		struct variable *va;

		va = VECTOR_POP(cf->variables);
		variable_value_clear(&va->va_val);
	}
	VECTOR_FREE(cf->variables);

	lexer_free(cf->lx);
	VECTOR_FREE(cf->empty_list);
}

int
config_parse(struct config *cf)
{
	struct buffer *bf;
	int error;

	arena_scope(cf->scratch, s);

	bf = arena_buffer_alloc(&s, 1 << 10);
	cf->lx = lexer_alloc(&(struct lexer_arg){
	    .path = cf->path,
	    .callbacks = {
		.read		= config_lexer_read,
		.serialize	= token_serialize,
		.arg		= bf,
	    },
	});
	if (cf->lx == NULL) {
		error = 1;
		goto out;
	}
	error = config_parse1(cf);

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

static struct variable *
config_find_or_create_list(struct config *cf, const char *name)
{
	if (!config_present(cf, name)) {
		struct variable_value val;

		variable_value_init(&val, LIST);
		config_append(cf, name, &val);
	}
	return config_find(cf, name);
}

static struct variable *
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
		vadef.va_val.list = cf->empty_list;
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
config_interpolate(struct config *cf)
{
	const char *str;

	str = interpolate_file("/dev/stdin", &(struct interpolate_arg){
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
	if (va == NULL)
		return NULL;

	bf = arena_buffer_alloc(s, 128);
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
	return buffer_str(bf);
}

static const char *
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

static const char **
config_regress_get_steps(struct config *cf)
{
	VECTOR(const char *) regress_no_parallel;
	VECTOR(const char *) steps;
	VECTOR(char *) regress;
	size_t i = 0;
	size_t nregress, r, s;

	regress = config_value(cf, "regress", list, NULL);
	nregress = VECTOR_LENGTH(regress);

	if (VECTOR_INIT(steps))
		err(1, NULL);
	if (VECTOR_RESERVE(steps, cf->steps.len + nregress))
		err(1, NULL);
	if (VECTOR_INIT(regress_no_parallel))
		err(1, NULL);

	/* Include synchronous steps up to ${regress}. */
	for (s = 0; s < cf->steps.len; s++) {
		if (cf->steps.ptr[s] == NULL)
			break;

		if (VECTOR_ALLOC(steps) == NULL)
			err(1, NULL);
		steps[i++] = cf->steps.ptr[s];
	}

	/* Include parallel ${regress} steps. */
	for (r = 0; r < nregress; r++) {
		const char *name;
		int parallel;

		arena_scope(cf->scratch, scratch);

		name = regressname(regress[r], "parallel", &scratch);
		parallel = config_value(cf, name, integer, 1);
		if (parallel) {
			if (VECTOR_ALLOC(steps) == NULL)
				err(1, NULL);
			steps[i++] = regress[r];
		} else {
			const char **dst;

			dst = VECTOR_ALLOC(regress_no_parallel);
			if (dst == NULL)
				err(1, NULL);
			*dst = regress[r];
		}
	}

	/* Include non-parallel ${regress} steps. */
	for (r = 0; r < VECTOR_LENGTH(regress_no_parallel); r++) {
		if (VECTOR_ALLOC(steps) == NULL)
			err(1, NULL);
		steps[i++] = regress_no_parallel[r];
	}

	/* Include remaining synchronous steps. */
	for (s++; s < cf->steps.len; s++) {
		if (VECTOR_ALLOC(steps) == NULL)
			err(1, NULL);
		steps[i++] = cf->steps.ptr[s];
	}

	VECTOR_FREE(regress_no_parallel);

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

	if (cf->mode == ROBSD_REGRESS)
		return config_regress_get_steps(cf);

	if (VECTOR_INIT(steps))
		err(1, NULL);
	if (VECTOR_RESERVE(steps, cf->steps.len))
		err(1, NULL);

	for (i = 0; i < cf->steps.len; i++) {
		if (VECTOR_ALLOC(steps) == NULL)
			err(1, NULL);
		steps[i] = cf->steps.ptr[i];
	}

	return steps;
}

static struct token *
config_lexer_read(struct lexer *lx, void *arg)
{
	struct lexer_state s;
	struct buffer *bf = (struct buffer *)arg;
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
		if (strcmp("no-parallel", buf) == 0)
			return lexer_emit(lx, &s, TOKEN_NO_PARALLEL);
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
	case TOKEN_NO_PARALLEL:
		return "NO-PARALLEL";
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
		VECTOR_FREE(val->list);
		break;
	}

	case STRING:
	case INTEGER:
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
		case 1:
			error = 1;
			break;
		case -1:
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

	gr = config_find_grammar_for_keyword(cf, tk->tk_str);
	if (gr == NULL) {
		lexer_warnx(cf->lx, tk->tk_lno, "unknown keyword '%s'",
		    tk->tk_str);
		return -1;
	}

	if ((gr->gr_flags & REP) == 0 && config_present(cf, tk->tk_str)) {
		lexer_warnx(cf->lx, tk->tk_lno,
		    "variable '%s' already defined", tk->tk_str);
		error = 1;
	}
	assert(gr->gr_fn != NULL);
	if (gr->gr_fn(cf, &val) == 0) {
		if (val.ptr != novalue)
			config_append(cf, tk->tk_str, &val);
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

static int
config_parse_boolean(struct config *cf, struct variable_value *val)
{
	struct token *tk;

	if (!lexer_expect(cf->lx, TOKEN_BOOLEAN, &tk))
		return 1;
	variable_value_init(val, INTEGER);
	val->integer = tk->tk_int;
	return 0;
}

static int
config_parse_string(struct config *cf, struct variable_value *val)
{
	struct token *tk;

	if (!lexer_expect(cf->lx, TOKEN_STRING, &tk))
		return 1;
	variable_value_init(val, STRING);
	val->str = tk->tk_str;
	return 0;
}

static int
config_parse_integer(struct config *cf, struct variable_value *val)
{
	struct token *tk;

	if (!lexer_expect(cf->lx, TOKEN_INTEGER, &tk))
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

static int
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

static int
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

static int
config_parse_regress(struct config *cf, struct variable_value *val)
{
	struct lexer *lx = cf->lx;
	struct token *tk;
	struct variable *regress;
	const char *path;
	char **dst;

	if (!lexer_expect(lx, TOKEN_STRING, &tk))
		return 1;
	path = tk->tk_str;

	for (;;) {
		const char *name;

		arena_scope(cf->scratch, s);

		if (lexer_if(lx, TOKEN_ENV, &tk)) {
			if (config_parse_regress_option_env(cf, path))
				return 1;
		} else if (lexer_if(lx, TOKEN_NO_PARALLEL, &tk)) {
			struct variable_value newval;

			name = regressname(path, "parallel", &s);
			variable_value_init(&newval, INTEGER);
			newval.integer = 0;
			config_append(cf, name, &newval);
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

			name = regressname(path, "quiet", &s);
			variable_value_init(&newval, INTEGER);
			newval.integer = 1;
			config_append(cf, name, &newval);
		} else if (lexer_if(lx, TOKEN_ROOT, &tk)) {
			struct variable_value newval;

			name = regressname(path, "root", &s);
			variable_value_init(&newval, INTEGER);
			newval.integer = 1;
			config_append(cf, name, &newval);
		} else if (lexer_if(lx, TOKEN_TARGET, &tk)) {
			struct variable_value newval;

			if (config_parse_string(cf, &newval))
				return 1;
			name = regressname(path, "target", &s);
			config_append(cf, name, &newval);
		} else {
			break;
		}
	}

	regress = config_find_or_create_list(cf, "regress");
	dst = VECTOR_ALLOC(regress->va_val.list);
	if (dst == NULL)
		err(1, NULL);
	*dst = arena_strdup(cf->eternal, path);
	val->ptr = novalue;
	return 0;
}

static int
config_parse_regress_option_env(struct config *cf, const char *path)
{
	struct variable_value defval, intval, newval;
	struct variable *va;
	const char *name, *str, *template;
	char **dst;

	if (config_parse_list(cf, &newval))
		return 1;

	arena_scope(cf->scratch, s);

	/* Prepend ${regress-env} for default enviroment. */
	name = regressname(path, "env", &s);
	variable_value_init(&defval, LIST);
	dst = VECTOR_ALLOC(defval.list);
	if (dst == NULL)
		err(1, NULL);
	*dst = arena_strdup(cf->eternal, "${regress-env}");
	variable_value_concat(&defval, &newval);
	va = config_append(cf, name, &defval);

	/* Do early interpolation to expand rdomain(s). */
	template = arena_sprintf(&s, "${%s}", name);
	str = config_interpolate_early(cf, template);
	if (str == NULL)
		return 1;
	variable_value_init(&intval, STRING);
	intval.str = str;
	variable_value_clear(&va->va_val);
	va->va_val = intval;

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
		config_append(cf, "regress-env", &def);
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
config_default_rdomain(struct config *cf, const char *UNUSED(name))
{
	static struct variable va;
	int rdomain;

	rdomain = cf->interpolate.rdomain++;
	if (rdomain == RDOMAIN_MAX)
		cf->interpolate.rdomain = rdomain = RDOMAIN_MIN;
	variable_value_init(&va.va_val, INTEGER);
	va.va_val.integer = rdomain;
	return &va;
}

static struct variable *
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

static int
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

static const char *
regressname(const char *path, const char *suffix, struct arena_scope *s)
{
	return arena_sprintf(s, "regress-%s-%s", path, suffix);
}
