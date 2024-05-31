#include "conf-priv.h"

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

static int
config_robsd_init(struct config *cf)
{
	if (cf->path == NULL)
		cf->path = "/etc/robsd.conf";

	config_copy_grammar(cf, robsd_grammar,
	    sizeof(robsd_grammar) / sizeof(robsd_grammar[0]));

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
