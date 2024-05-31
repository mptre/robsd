#include "config.h"

#include "libks/compiler.h"

#include "conf-priv.h"
#include "conf.h"
#include "variable-value.h"

static const struct grammar robsd_ports_grammar[] = {
	{ "chroot",		STRING,		config_parse_string,	REQ,	{ NULL } },
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

static struct config_step robsd_ports_steps[] = {
	{ "env",	{ "${exec-dir}/robsd-env.sh" },			{0} },
	{ "cvs",	{ "${exec-dir}/robsd-cvs.sh" },			{0} },
	{ "clean",	{ "${exec-dir}/robsd-ports-clean.sh" },		{0} },
	{ "proot",	{ "${exec-dir}/robsd-ports-proot.sh" },		{0} },
	{ "patch",	{ "${exec-dir}/robsd-patch.sh" },		{0} },
	{ "dpb",	{ "${exec-dir}/robsd-ports-dpb.sh" },		{0} },
	{ "distrib",	{ "${exec-dir}/robsd-ports-distrib.sh" },	{0} },
	{ "revert",	{ "${exec-dir}/robsd-revert.sh" },		{0} },
	{ "dmesg",	{ "${exec-dir}/robsd-dmesg.sh" },		{0} },
	{ "end",	{ "/dev/null" },				{0} },
};

static int
config_robsd_ports_init(struct config *cf)
{
	if (cf->path == NULL)
		cf->path = "/etc/robsd-ports.conf";

	config_copy_grammar(cf, robsd_ports_grammar,
	    sizeof(robsd_ports_grammar) / sizeof(robsd_ports_grammar[0]));

	cf->steps.ptr = robsd_ports_steps;
	cf->steps.len = sizeof(robsd_ports_steps) /
	    sizeof(robsd_ports_steps[0]);

	return 0;
}

static void
config_robsd_ports_free(struct config *UNUSED(cf))
{
}

static void
config_robsd_ports_after_parse(struct config *UNUSED(cf))
{
}

const struct config_callbacks *
config_robsd_ports_callbacks(void)
{
	static const struct config_callbacks callbacks = {
		.init		= config_robsd_ports_init,
		.free		= config_robsd_ports_free,
		.after_parse	= config_robsd_ports_after_parse,
		.get_steps	= config_default_get_steps,
	};

	return &callbacks;
}
