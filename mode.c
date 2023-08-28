#include "mode.h"

#include "config.h"

#include <string.h>

int
robsd_mode_parse(const char *mode, enum robsd_mode *res)
{
	if (strcmp(mode, "robsd") == 0)
		*res = CONFIG_ROBSD;
	else if (strcmp(mode, "robsd-cross") == 0)
		*res = CONFIG_ROBSD_CROSS;
	else if (strcmp(mode, "robsd-ports") == 0)
		*res = CONFIG_ROBSD_PORTS;
	else if (strcmp(mode, "robsd-regress") == 0)
		*res = CONFIG_ROBSD_REGRESS;
	else
		return 1;
	return 0;
}

const char *
robsd_mode_str(enum robsd_mode mode)
{
	switch (mode) {
	case CONFIG_ROBSD:
		return "robsd";
	case CONFIG_ROBSD_CROSS:
		return "robsd-cross";
	case CONFIG_ROBSD_PORTS:
		return "robsd-ports";
	case CONFIG_ROBSD_REGRESS:
		return "robsd-regress";
	}
	return "unknown";
}
