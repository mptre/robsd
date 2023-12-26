#include "config.h"

#include "libks/compiler.h"
#include "libks/fuzzer.h"

#include "step.h"

static void
target(const char *path, void *UNUSED(userdata))
{
	struct step_file *step_file;

	step_file = steps_parse(path);
	steps_free(step_file);
}
FUZZER_TARGET_FILE(target);
