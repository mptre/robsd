#include "config.h"

#include <err.h>

#include "libks/arena-vector.h"
#include "libks/arena.h"
#include "libks/arithmetic.h"
#include "libks/compiler.h"
#include "libks/vector.h"

#include "conf-priv.h"
#include "conf-token.h"
#include "conf.h"
#include "lexer.h"
#include "token.h"
#include "variable-value.h"

/*
 * Bounds for rdomain, favor something large enough to not conflict with
 * existing ones.
 */
#define RDOMAIN_MIN	11
#define RDOMAIN_MAX	256

static int	config_parse_regress(struct config *, struct variable_value *);
static int	config_parse_regress_option_env(struct config *, const char *);
static int	config_parse_regress_env(struct config *,
    struct variable_value *);
static int	config_parse_regress_timeout(struct config *,
    struct variable_value *);

static struct variable	*config_default_parallel(struct config *, const char *);
static struct variable	*config_default_rdomain(struct config *, const char *);
static struct variable	*config_default_regress_targets(struct config *,
    const char *);

static const struct grammar robsd_regress_grammar[] = {
	{ "parallel",		INTEGER,	config_parse_boolean,		0,		{ D_I32(1) } },
	{ "rdonly",		INTEGER,	config_parse_boolean,		0,		{ NULL } },
	{ "sudo",		STRING,		config_parse_string,		0,		{ "doas -n" } },
	{ "bsd-diff",		LIST,		config_parse_glob,		0,		{ NULL } },
	{ "bsd-srcdir",		DIRECTORY,	config_parse_directory,		0,		{ "/usr/src" } },
	{ "cvs-root",		STRING,		config_parse_string,		0,		{ NULL } },
	{ "cvs-user",		STRING,		config_parse_user,		0,		{ NULL } },
	{ "rdomain",		INTEGER,	NULL,				FUN|EARLY,	{ D_FUN(config_default_rdomain) } },
	{ "regress",		LIST,		config_parse_regress,		REQ|REP,	{ NULL } },
	{ "regress-env",	LIST,		config_parse_regress_env,	REP,		{ NULL } },
	{ "regress-user",	STRING,		config_parse_user,		0,		{ "${build-user}" } },
	{ "regress-timeout",	INTEGER,	config_parse_regress_timeout,	0,		{ NULL } },
	{ "regress-*-env",	STRING,		NULL,				PAT|EARLY,	{ "${regress-env}" } },
	{ "regress-*-targets",	LIST,		NULL,				PAT|FUN,	{ D_FUN(config_default_regress_targets) } },
	{ "regress-*-parallel",	INTEGER,	NULL,				PAT|FUN,	{ D_FUN(config_default_parallel) } },
};

static struct config_step robsd_regress_steps[] = {
	{ "env",	{ "${exec-dir}/robsd-env.sh" },			{0} },
	{ "pkg-add",	{ "${exec-dir}/robsd-regress-pkg-add.sh" },	{0} },
	{ "cvs",	{ "${exec-dir}/robsd-cvs.sh" },			{0} },
	{ "patch",	{ "${exec-dir}/robsd-patch.sh" },		{0} },
	{ "obj",	{ "${exec-dir}/robsd-regress-obj.sh" },		{0} },
	{ "mount",	{ "${exec-dir}/robsd-regress-mount.sh" },	{0} },
	{ NULL,		{ NULL },					{0} }, /* ${regress} */
	{ "umount",	{ "${exec-dir}/robsd-regress-umount.sh" },	{0} },
	{ "revert",	{ "${exec-dir}/robsd-revert.sh" },		{0} },
	{ "pkg-del",	{ "${exec-dir}/robsd-regress-pkg-del.sh" },	{0} },
	{ "dmesg",	{ "${exec-dir}/robsd-dmesg.sh" },		{0} },
	{ "end",	{ "/dev/null" },				{0} },
};

static const char *
regressname(const char *path, const char *suffix, struct arena_scope *s)
{
	return arena_sprintf(s, "regress-%s-%s", path, suffix);
}

static void
config_robsd_regress_after_parse(struct config *UNUSED(cf))
{
}

static int
config_robsd_regress_init(struct config *cf)
{
	if (cf->path == NULL)
		cf->path = "/etc/robsd-regress.conf";

	config_copy_grammar(cf, robsd_regress_grammar,
	    sizeof(robsd_regress_grammar) / sizeof(robsd_regress_grammar[0]));

	cf->steps.ptr = robsd_regress_steps;
	cf->steps.len = sizeof(robsd_regress_steps) /
	    sizeof(robsd_regress_steps[0]);

	cf->interpolate.rdomain = RDOMAIN_MIN;

	return 0;
}

static void
config_robsd_regress_free(struct config *UNUSED(cf))
{
}

static int
is_parallel(struct config *cf, const char *step_name)
{
	const char *name;

	arena_scope(cf->arena.scratch, s);

	if (!config_value(cf, "parallel", integer, 1))
		return 0;
	name = regressname(step_name, "parallel", &s);
	return config_value(cf, name, integer, 1);
}

static struct config_step *
config_robsd_regress_get_steps(struct config *cf, struct arena_scope *s)
{
	VECTOR(const char *) regress_no_parallel;
	VECTOR(struct config_step) steps;
	VECTOR(char *) regress;
	size_t i, nregress, r;

	regress = config_value(cf, "regress", list, NULL);
	nregress = VECTOR_LENGTH(regress);

	ARENA_VECTOR_INIT(s, steps, cf->steps.len + nregress);
	arena_cleanup(s, config_steps_free, steps);

	ARENA_VECTOR_INIT(s, regress_no_parallel, 0);

	/* Include synchronous steps up to ${regress}. */
	for (i = 0; i < cf->steps.len; i++) {
		const struct config_step *cs = &cf->steps.ptr[i];

		if (cs->name == NULL)
			break;

		config_steps_add_script(steps, cs->command.path, cs->name);
	}

	/* Include parallel ${regress} steps. */
	for (r = 0; r < nregress; r++) {
		int parallel;

		parallel = is_parallel(cf, regress[r]);
		if (parallel) {
			struct config_step *cs;

			cs = config_steps_add_script(steps,
			    "${exec-dir}/robsd-regress-exec.sh", regress[r]);
			cs->flags.parallel = 1;
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
		config_steps_add_script(steps,
		    "${exec-dir}/robsd-regress-exec.sh",
		    regress_no_parallel[r]);
	}

	/* Include remaining synchronous steps. */
	for (i++; i < cf->steps.len; i++) {
		const struct config_step *cs = &cf->steps.ptr[i];

		config_steps_add_script(steps, cs->command.path, cs->name);
	}

	return steps;
}

const struct config_callbacks *
config_robsd_regress_callbacks(void)
{
	static const struct config_callbacks callbacks = {
		.init		= config_robsd_regress_init,
		.free		= config_robsd_regress_free,
		.after_parse	= config_robsd_regress_after_parse,
		.get_steps	= config_robsd_regress_get_steps,
	};

	return &callbacks;
}

static int
config_parse_regress(struct config *cf, struct variable_value *UNUSED(val))
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

		arena_scope(cf->arena.scratch, s);

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
		} else if (lexer_if(lx, TOKEN_TARGETS, &tk)) {
			struct variable_value newval;
			struct variable *targets;

			if (config_parse_list(cf, &newval))
				return 1;
			name = regressname(path, "targets", &s);
			targets = config_find_or_create_list(cf, name);
			variable_value_concat(&targets->va_val, &newval);
		} else {
			break;
		}
	}

	regress = config_find_or_create_list(cf, "regress");
	dst = VECTOR_ALLOC(regress->va_val.list);
	if (dst == NULL)
		err(1, NULL);
	*dst = arena_strdup(cf->arena.eternal_scope, path);
	return CONFIG_NOP;
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

	arena_scope(cf->arena.scratch, s);

	/* Prepend ${regress-env} for default enviroment. */
	name = regressname(path, "env", &s);
	variable_value_init(&defval, LIST);
	dst = VECTOR_ALLOC(defval.list);
	if (dst == NULL)
		err(1, NULL);
	*dst = arena_strdup(cf->arena.eternal_scope, "${regress-env}");
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
	return CONFIG_NOP;
}

static int
config_parse_regress_timeout(struct config *cf, struct variable_value *val)
{
	struct token *tk;
	struct variable_value timeout;
	int scalar = 0;

	if (config_parse_integer(cf, &timeout) == CONFIG_ERROR)
		return CONFIG_ERROR;
	if (lexer_if(cf->lx, TOKEN_SECONDS, &tk)) {
		scalar = 1;
	} else if (lexer_if(cf->lx, TOKEN_MINUTES, &tk)) {
		scalar = 60;
	} else if (lexer_if(cf->lx, TOKEN_HOURS, &tk)) {
		scalar = 3600;
	} else {
		struct token *nx;

		if (lexer_next(cf->lx, &nx))
			lexer_warnx(cf->lx, nx->tk_lno, "unknown timeout unit");
		return CONFIG_ERROR;
	}

	if (KS_i32_mul_overflow(scalar, timeout.integer, &timeout.integer)) {
		lexer_warnx(cf->lx, tk->tk_lno, "timeout too large");
		return CONFIG_ERROR;
	}

	variable_value_init(val, INTEGER);
	val->integer = timeout.integer;
	return CONFIG_APPEND;
}

static struct variable *
config_default_parallel(struct config *cf, const char *UNUSED(name))
{
	return config_find(cf, "parallel");
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
config_default_regress_targets(struct config *cf, const char *name)
{
	struct variable_value val;
	char **dst;

	variable_value_init(&val, LIST);
	dst = VECTOR_ALLOC(val.list);
	if (dst == NULL)
		err(1, NULL);
	*dst = arena_strdup(cf->arena.eternal_scope, "regress");
	return config_append(cf, name, &val);
}
