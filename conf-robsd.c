#include "conf-priv.h"
#include "conf.h"
#include "variable-value.h"

static const struct grammar robsd_grammar[] = {
	{ "destdir",		DIRECTORY,	config_parse_directory,	REQ,	{ NULL } },
	{ "kernel",		STRING,		config_parse_string,	0,	{ "GENERIC.MP" } },
	{ "reboot",		INTEGER,	config_parse_boolean,	0,	{ NULL } },
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

static const struct config_step robsd_steps[] = {
	{ "env",	{ "${exec-dir}/robsd-env.sh" },		{0} },
	{ "cvs",	{ "${exec-dir}/robsd-cvs.sh" },		{0} },
	{ "patch",	{ "${exec-dir}/robsd-patch.sh" },	{0} },
	{ "kernel",	{ "${exec-dir}/robsd-kernel.sh" },	{0} },
	{ "reboot",	{ "/dev/null" },			{0} },
	{ "env",	{ "${exec-dir}/robsd-env.sh" },		{0} },
	{ "base",	{ "${exec-dir}/robsd-base.sh" },	{0} },
	{ "release",	{ "${exec-dir}/robsd-release.sh" },	{0} },
	{ "checkflist",	{ "${exec-dir}/robsd-checkflist.sh" },	{0} },
	{ "xbase",	{ "${exec-dir}/robsd-xbase.sh" },	{0} },
	{ "xrelease",	{ "${exec-dir}/robsd-xrelease.sh" },	{0} },
	{ "image",	{ "${exec-dir}/robsd-image.sh" },	{0} },
	{ "hash",	{ "${exec-dir}/robsd-hash.sh" },	{0} },
	{ "revert",	{ "${exec-dir}/robsd-revert.sh" },	{0} },
	{ "distrib",	{ "${exec-dir}/robsd-distrib.sh" },	{0} },
	{ "dmesg",	{ "${exec-dir}/robsd-dmesg.sh" },	{0} },
	{ "end",	{ "/dev/null" },			{0} },
};

static int
config_robsd_init(struct config *cf)
{
	if (cf->path == NULL)
		cf->path = "/etc/robsd.conf";

	config_copy_grammar(cf, robsd_grammar,
	    sizeof(robsd_grammar) / sizeof(robsd_grammar[0]));

	cf->steps.ptr = robsd_steps;
	cf->steps.len = sizeof(robsd_steps) / sizeof(robsd_steps[0]);

	return 0;
}

const struct config_callbacks *
config_robsd_callbacks(void)
{
	static const struct config_callbacks callbacks = {
		.init		= config_robsd_init,
		.get_steps	= config_default_get_steps,
	};

	return &callbacks;
}
