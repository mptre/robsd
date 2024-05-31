#include <stddef.h>	/* size_t */

#include "mode.h"

struct config {
	struct arena_scope		 *eternal;
	struct arena			 *scratch;
	struct lexer			 *lx;
	const char			 *path;

	const struct config_callbacks	 *callbacks;

	const struct grammar		**grammar;	/* VECTOR(const struct grammar *) */

	struct {
		const struct config_step	*ptr;
		size_t				 len;
	} steps;

	struct {
		int	early;
		int	rdomain;
	} interpolate;

	struct variable			 *variables;	/* VECTOR(struct variable) */

	/* Sentinel used for absent list variables during interpolation. */
	char				**empty_list;	/* VECTOR(char *) */

	enum robsd_mode			  mode;
};

struct config_callbacks {
	int	(*init)(struct config *);
};

const struct config_callbacks	*config_robsd_callbacks(void);
const struct config_callbacks	*config_robsd_cross_callbacks(void);
const struct config_callbacks	*config_robsd_ports_callbacks(void);
const struct config_callbacks	*config_robsd_regress_callbacks(void);
