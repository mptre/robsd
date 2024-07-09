#include "alloc.h"

#include "config.h"

#include <err.h>
#include <stdlib.h>
#include <string.h>

char *
estrdup(const char *str)
{
	void *p;

	p = strdup(str);
	if (p == NULL)
		err(1, NULL);
	return p;
}

char *
estrndup(const char *str, size_t size)
{
	void *p;

	p = strndup(str, size);
	if (p == NULL)
		err(1, NULL);
	return p;
}
