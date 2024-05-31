#include "conf-priv.h"

static const struct grammar robsd_cross_grammar[] = {
	{ "crossdir",	STRING,		config_parse_string,	REQ,	{ NULL } },
	{ "bsd-srcdir",	DIRECTORY,	config_parse_directory,	0,	{ "/usr/src" } },
};

static int
config_robsd_cross_init(struct config *cf)
{
	if (cf->path == NULL)
		cf->path = "/etc/robsd-cross.conf";

	config_copy_grammar(cf, robsd_cross_grammar,
	    sizeof(robsd_cross_grammar) / sizeof(robsd_cross_grammar[0]));

	return 0;
}

const struct config_callbacks *
config_robsd_cross_callbacks(void)
{
	static const struct config_callbacks callbacks = {
		.init		= config_robsd_cross_init,
		.get_steps	= config_default_get_steps,
	};

	return &callbacks;
}
