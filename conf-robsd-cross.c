#include "conf-priv.h"

static int
config_robsd_cross_init(struct config *cf)
{
	if (cf->path == NULL)
		cf->path = "/etc/robsd-cross.conf";
	return 0;
}

const struct config_callbacks *
config_robsd_cross_callbacks(void)
{
	static const struct config_callbacks callbacks = {
		.init	= config_robsd_cross_init,
	};

	return &callbacks;
}
