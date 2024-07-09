#include "mode.h"

#define FOR_TOKEN_TYPES(OP)						\
	/* sentinels */							\
	OP(UNKNOWN,		NULL,		0)			\
	/* types */							\
	OP(BOOLEAN,		NULL,		0)			\
	OP(INTEGER,		NULL,		0)			\
	OP(STRING,		NULL,		0)			\
	OP(KEYWORD,		NULL,		0)			\
	/* literals */							\
	OP(LBRACE,		"{",		0)			\
	OP(RBRACE,		"}",		0)			\
	/* keywords */							\
	OP(COMMAND,		"command",	0)			\
	OP(ENV,			"env",		0)			\
	OP(HOURS,		"h",		0)			\
	OP(MINUTES,		"m",		0)			\
	OP(NO_PARALLEL,		"no-parallel",	0)			\
	OP(OBJ,			"obj",		0)			\
	OP(PACKAGES,		"packages",	0)			\
	OP(PARALLEL,		"parallel",	CANVAS)			\
	OP(QUIET,		"quiet",	0)			\
	OP(ROOT,		"root",		0)			\
	OP(SECONDS,		"s",		0)			\
	OP(TARGETS,		"targets",	0)

enum token_type {
#define OP(name, ...) TOKEN_ ## name,
	FOR_TOKEN_TYPES(OP)
#undef OP
};

const char	*token_type_str(enum token_type);
