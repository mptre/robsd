#include "conf-priv.h"
#include "conf.h"
#include "variable-value.h"

static const struct grammar robsd_cross_grammar[] = {
	{ "crossdir",	STRING,		config_parse_string,	REQ,	{ NULL } },
	{ "bsd-srcdir",	DIRECTORY,	config_parse_directory,	0,	{ "/usr/src" } },
};

static const struct config_step robsd_cross_steps[] = {
	{ "env",	{ "${exec-dir}/robsd-env.sh" },			{0} },
	{ "dirs",	{ "${exec-dir}/robsd-cross-dirs.sh" },		{0} },
	{ "tools",	{ "${exec-dir}/robsd-cross-tools.sh" },		{0} },
	{ "distrib",	{ "${exec-dir}/robsd-cross-distrib.sh" },	{0} },
	{ "dmesg",	{ "${exec-dir}/robsd-dmesg.sh" },		{0} },
	{ "end",	{ "/dev/null" },				{0} },
};

static int
config_robsd_cross_init(struct config *cf)
{
	if (cf->path == NULL)
		cf->path = "/etc/robsd-cross.conf";

	config_copy_grammar(cf, robsd_cross_grammar,
	    sizeof(robsd_cross_grammar) / sizeof(robsd_cross_grammar[0]));

	cf->steps.ptr = robsd_cross_steps;
	cf->steps.len = sizeof(robsd_cross_steps) /
	    sizeof(robsd_cross_steps[0]);

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
