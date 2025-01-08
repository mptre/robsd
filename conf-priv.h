#include <stddef.h>	/* size_t */

#include "mode.h"
#include "variable-value.h"

struct lexer;

/* Return values for config parser routines. */
#define CONFIG_APPEND	0
#define CONFIG_ERROR	1
#define CONFIG_NOP	2
#define CONFIG_FATAL    3

struct config_steps {
	struct config_step      *v; /* VECTOR(struct config_step) */
};

struct config {
	const char			 *path;
	const struct config_callbacks	 *callbacks;
	const struct grammar		**grammar;	/* VECTOR(const struct grammar *) */
	struct variable			 *variables;	/* VECTOR(struct variable) */
	struct token_type_lookup	 *lookup;

	struct {
		struct arena_scope	*eternal_scope;
		struct arena		*scratch;
	} arena;

	struct {
		const struct config_step	*ptr;
		size_t				 len;
	} steps;

	struct {
		struct config_steps     steps;
	} canvas;

	struct {
		int	early;
		int	rdomain;
		int	trace;
	} interpolate;

	enum robsd_mode			  mode;
};

struct config_callbacks {
	int			 (*init)(struct config *);
	void			 (*free)(struct config *);
	void			 (*after_parse)(struct config *);
	struct config_step	*(*get_steps)(struct config *,
	    struct arena_scope *);
};

struct grammar {
	const char		*gr_kw;
	enum variable_type	 gr_type;
	int			 (*gr_fn)(struct config *,
	    struct lexer *, struct variable_value *);
	unsigned int		 gr_flags;
#define REQ	0x00000001u	/* required */
#define REP	0x00000002u	/* may be repeated */
#define PAT	0x00000004u	/* fnmatch(3) keyword fallback */
#define FUN	0x00000008u	/* default obtain through gr_default.fun */
#define EARLY	0x00000010u	/* interpolate early */

	union {
		const char	*s8;
		struct variable	*(*fun)(struct config *, const char *);
		int		 i32;
#define D_FUN(x)	.fun = (x)
#define D_I32(x)	.i32 = (x)
	} gr_default;
};

struct variable {
	char			*va_name;
	size_t			 va_namelen;
	struct variable_value	 va_val;
};

const struct config_callbacks	*config_robsd_callbacks(void);
const struct config_callbacks	*config_robsd_cross_callbacks(void);
const struct config_callbacks	*config_robsd_ports_callbacks(void);
const struct config_callbacks	*config_robsd_regress_callbacks(void);
const struct config_callbacks	*config_canvas_callbacks(void);

struct variable		*config_append(struct config *, const char *,
    const struct variable_value *);
void			 config_copy_grammar(struct config *,
    const struct grammar *,
    unsigned int);
struct config_step	*config_default_get_steps(struct config *,
    struct arena_scope *);
struct variable		*config_find(struct config *, const char *);
struct variable		*config_find_or_create_list(struct config *,
    const char *);
const char		*config_interpolate_early(struct config *,
    const char *);
int			 config_present(const struct config *, const char *);

struct config_step	*config_steps_add_script(struct config_steps *,
    const char *, const char *);
void			 config_steps_free(void *);

int	config_parse_boolean(struct config *, struct lexer *,
    struct variable_value *);
int	config_parse_directory(struct config *, struct lexer *,
    struct variable_value *);
int	config_parse_glob(struct config *, struct lexer *,
    struct variable_value *);
int	config_parse_list(struct config *, struct lexer *,
    struct variable_value *);
int	config_parse_string(struct config *, struct lexer *,
    struct variable_value *);
int	config_parse_timeout(struct config *, struct lexer *,
    struct variable_value *);
int	config_parse_user(struct config *, struct lexer *,
    struct variable_value *);
