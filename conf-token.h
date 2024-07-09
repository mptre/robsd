#include "mode.h"

struct arena_scope;

#define FOR_TOKEN_TYPES(OP)						\
	/* sentinels */							\
	OP(UNKNOWN,		"",		0)			\
	/* types */							\
	OP(BOOLEAN,		"",		0)			\
	OP(INTEGER,		"",		0)			\
	OP(STRING,		"",		0)			\
	OP(KEYWORD,		"",		0)			\
	/* literals */							\
	OP(LBRACE,		"{",		0)			\
	OP(RBRACE,		"}",		0)			\
	/* keywords */							\
	OP(COMMAND,		"command",	CANVAS)			\
	OP(ENV,			"env",		ROBSD_REGRESS)		\
	OP(HOURS,		"h",		ROBSD_REGRESS)		\
	OP(MINUTES,		"m",		ROBSD_REGRESS)		\
	OP(NO,			"no",		0)			\
	OP(NO_PARALLEL,		"no-parallel",	ROBSD_REGRESS)		\
	OP(OBJ,			"obj",		ROBSD_REGRESS)		\
	OP(PACKAGES,		"packages",	ROBSD_REGRESS)		\
	OP(PARALLEL,		"parallel",	CANVAS)			\
	OP(QUIET,		"quiet",	ROBSD_REGRESS)		\
	OP(ROOT,		"root",		ROBSD_REGRESS)		\
	OP(SECONDS,		"s",		0)			\
	OP(TARGETS,		"targets",	ROBSD_REGRESS)		\
	OP(YES,			"yes",		0)

enum token_type {
#define OP(name, ...) TOKEN_ ## name,
	FOR_TOKEN_TYPES(OP)
#undef OP
};

struct token_type_lookup	*token_type_lookup_alloc(enum robsd_mode,
    struct arena_scope *);
void				 token_type_lookup_free(
    struct token_type_lookup *);
enum token_type			 token_type_lookup(
    const struct token_type_lookup *, const char *);

const char	*token_type_str(enum token_type);
