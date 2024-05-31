#include "conf-priv.h"

static int
config_robsd_regress_init(struct config *cf)
{
	if (cf->path == NULL)
		cf->path = "/etc/robsd-regress.conf";
	return 0;
}

const struct config_callbacks *
config_robsd_regress_callbacks(void)
{
	static const struct config_callbacks callbacks = {
		.init	= config_robsd_regress_init,
	};

	return &callbacks;
}
