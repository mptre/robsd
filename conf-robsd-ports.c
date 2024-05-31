#include "conf-priv.h"

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

static int
config_robsd_ports_init(struct config *cf)
{
	if (cf->path == NULL)
		cf->path = "/etc/robsd-ports.conf";

	config_copy_grammar(cf, robsd_ports_grammar,
	    sizeof(robsd_ports_grammar) / sizeof(robsd_ports_grammar[0]));

	return 0;
}

const struct config_callbacks *
config_robsd_ports_callbacks(void)
{
	static const struct config_callbacks callbacks = {
		.init		= config_robsd_ports_init,
		.get_steps	= config_default_get_steps,
	};

	return &callbacks;
}
