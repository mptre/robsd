#include <stddef.h>	/* size_t */

#include "mode.h"
#include "variable-value.h"

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

struct grammar {
	const char		*gr_kw;
	enum variable_type	 gr_type;
	int			 (*gr_fn)(struct config *,
	    struct variable_value *);
	unsigned int		 gr_flags;
#define REQ	0x00000001u	/* required */
#define REP	0x00000002u	/* may be repeated */
#define PAT	0x00000004u	/* fnmatch(3) keyword fallback */
#define FUN	0x00000008u	/* default obtain through function call */
#define EARLY	0x00000010u	/* interpolate early */

	union {
		const void	*ptr;
		struct variable	*(*fun)(struct config *, const char *);
		int		 i32;
#define D_FUN(x)	.fun = (x)
#define D_I32(x)	.i32 = (x)
	} gr_default;
};

const struct config_callbacks	*config_robsd_callbacks(void);
const struct config_callbacks	*config_robsd_cross_callbacks(void);
const struct config_callbacks	*config_robsd_ports_callbacks(void);
const struct config_callbacks	*config_robsd_regress_callbacks(void);
