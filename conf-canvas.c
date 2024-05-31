#include "config.h"

#include <err.h>

#include "libks/compiler.h"
#include "libks/vector.h"

#include "conf-priv.h"
#include "conf.h"
#include "lexer.h"
#include "token.h"
#include "variable-value.h"

static int	config_parse_canvas_directory(struct config *,
    struct variable_value *);
static int	config_parse_canvas_step(struct config *,
    struct variable_value *);

static const struct grammar canvas_grammar[] = {
	{ "canvas-name",	STRING,		config_parse_string,		REQ,		{ NULL } },
	{ "canvas-dir",		STRING,		config_parse_canvas_directory,	REQ,		{ NULL } },
	{ "step",		INVALID,	config_parse_canvas_step,	REQ|REP,	{ NULL } },
};

static int
config_canvas_init(struct config *cf)
{
	if (cf->path == NULL) {
		warnx("configuration file missing");
		return 1;
	}

	config_copy_grammar(cf, canvas_grammar,
	    sizeof(canvas_grammar) / sizeof(canvas_grammar[0]));

	if (VECTOR_INIT(cf->canvas.steps))
		err(1, NULL);

	return 0;
}

static void
config_canvas_free(struct config *cf)
{
	while (!VECTOR_EMPTY(cf->canvas.steps)) {
		struct config_step *cs;

		cs = VECTOR_POP(cf->canvas.steps);
		variable_value_clear(&cs->command.val);
	}

	VECTOR_FREE(cf->canvas.steps);
}

static void
config_canvas_after_parse(struct config *cf)
{
	config_steps_add_script(cf->canvas.steps, "/dev/null", "end");
}

static struct config_step *
config_canvas_get_steps(struct config *cf, struct arena_scope *UNUSED(s))
{
	return cf->canvas.steps;
}

const struct config_callbacks *
config_canvas_callbacks(void)
{
	static const struct config_callbacks callbacks = {
		.init		= config_canvas_init,
		.free		= config_canvas_free,
		.after_parse	= config_canvas_after_parse,
		.get_steps	= config_canvas_get_steps,
	};

	return &callbacks;
}

static int
config_parse_canvas_directory(struct config *cf, struct variable_value *val)
{
	int error;

	error = config_parse_directory(cf, val);
	if (error)
		return error;
	config_append(cf, "canvas-dir", val);
	/* Add alias to satisfy required variable. */
	config_append(cf, "robsddir", val);
	return CONFIG_NOP;
}

static int
config_parse_canvas_step(struct config *cf, struct variable_value *UNUSED(val))
{
	struct variable_value name = {0};
	struct variable_value command = {0};
	struct config_step *cs;
	struct token *tk;
	unsigned int parallel = 0;
	int error;

	error = config_parse_string(cf, &name);
	if (error)
		return error;

	for (;;) {
		if (lexer_if(cf->lx, TOKEN_COMMAND, &tk)) {
			error = config_parse_list(cf, &command);
			if (error)
				goto err;
		} else if (lexer_if(cf->lx, TOKEN_PARALLEL, &tk)) {
			parallel = 1;
		} else {
			break;
		}
	}

	if (!is_variable_value_valid(&command) || VECTOR_EMPTY(command.list)) {
		lexer_warnx(cf->lx, lexer_back(cf->lx, &tk) ? tk->tk_lno : 0,
		    "mandatory step option 'command' missing");
		goto err;
	}

	/* Add required variable sentinel. */
	if (VECTOR_EMPTY(cf->canvas.steps)) {
		struct variable_value empty = {0};

		config_append(cf, "step", &empty);
	}

	cs = VECTOR_CALLOC(cf->canvas.steps);
	if (cs == NULL)
		err(1, NULL);
	cs->name = name.str;
	cs->command.val = command;
	cs->flags.parallel = parallel;

	return CONFIG_NOP;

err:
	variable_value_clear(&command);
	return CONFIG_ERROR;
}
