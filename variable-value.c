#include "variable-value.h"

#include "config.h"

#include <assert.h>
#include <err.h>
#include <string.h>

#include "libks/vector.h"

void
variable_value_init(struct variable_value *val, enum variable_type type)
{
	memset(val, 0, sizeof(*val));
	val->type = type;

	switch (type) {
	case LIST:
		if (VECTOR_INIT(val->list))
			err(1, NULL);
		break;
	case INVALID:
	case INTEGER:
	case STRING:
	case DIRECTORY:
		break;
	}
}

void
variable_value_clear(struct variable_value *val)
{
	switch (val->type) {
	case LIST: {
		VECTOR_FREE(val->list);
		break;
	}

	case INVALID:
	case STRING:
	case INTEGER:
	case DIRECTORY:
		break;
	}
}

void
variable_value_append(struct variable_value *val, const char *str)
{
	char **dst;

	assert(val->type == LIST);

	dst = VECTOR_ALLOC(val->list);
	if (dst == NULL)
		err(1, NULL);
	*dst = (char *)str;
}

void
variable_value_concat(struct variable_value *dst, struct variable_value *src)
{
	size_t i;

	assert(dst->type == LIST && src->type == LIST);

	for (i = 0; i < VECTOR_LENGTH(src->list); i++) {
		char **str;

		str = VECTOR_ALLOC(dst->list);
		if (str == NULL)
			err(1, NULL);
		*str = src->list[i];
	}
	variable_value_clear(src);
}
