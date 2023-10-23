#include "config.h"

#include <stddef.h>

#include "step.h"

int
main(void)
{
	struct step_file *step_file;
	int error = 0;

	step_file = steps_parse("/dev/stdin");
	if (step_file == NULL)
		error = 1;
	steps_free(step_file);
	return error;
}
