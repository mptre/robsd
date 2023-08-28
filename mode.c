#include "mode.h"

#include "config.h"

#include <string.h>

int
robsd_mode_parse(const char *mode, enum robsd_mode *res)
{
	if (strcmp(mode, "robsd") == 0)
		*res = ROBSD;
	else if (strcmp(mode, "robsd-cross") == 0)
		*res = ROBSD_CROSS;
	else if (strcmp(mode, "robsd-ports") == 0)
		*res = ROBSD_PORTS;
	else if (strcmp(mode, "robsd-regress") == 0)
		*res = ROBSD_REGRESS;
	else
		return 1;
	return 0;
}

const char *
robsd_mode_str(enum robsd_mode mode)
{
	switch (mode) {
	case ROBSD:
		return "robsd";
	case ROBSD_CROSS:
		return "robsd-cross";
	case ROBSD_PORTS:
		return "robsd-ports";
	case ROBSD_REGRESS:
		return "robsd-regress";
	}
	return "unknown";
}
