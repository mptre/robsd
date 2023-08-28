#include "mode.h"

#include "config.h"

#include <string.h>

int
robsd_mode_parse(const char *mode, enum robsd_mode *res)
{
#define OP(c, s) do {						\
	if (strcmp(mode, (s)) == 0) {				\
		*res = (c);					\
		return 0;					\
	}							\
} while (0);
	FOR_ROBSD_MODES(OP)
#undef OP

	return 1;
}

const char *
robsd_mode_str(enum robsd_mode mode)
{
	switch (mode) {
#define OP(c, s) case c: return s;
	FOR_ROBSD_MODES(OP)
#undef OP
	}
	return "unknown";
}
