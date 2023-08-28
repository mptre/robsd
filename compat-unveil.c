#include "config.h"

extern int unused;

#ifndef HAVE_UNVEIL

#include "libks/compiler.h"

int
unveil(const char *UNUSED(path), const char *UNUSED(permissions))
{
	return 0;
}

#endif
