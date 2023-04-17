#include "config.h"

#include <stddef.h>

#include "conf.h"

int
main(int argc, char *argv[])
{
	struct config *config = NULL;
	const char *mode = "robsd";
	int error;

	if (argc == 2)
		mode = argv[1];

	config = config_alloc(mode, "/dev/stdin");
	if (config == NULL)
		return 1;
	error = config_parse(config);
	config_free(config);
	return error;
}
