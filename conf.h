#include "mode.h"
#include "variable-value.h"

struct arena;
struct arena_scope;

#define CONFIG_STEPS_TRACE_COMMAND				0x00000001u

#define config_value(config, name, field, fallback) __extension__ ({	\
	struct variable_value _va;					\
	typeof(_va.field) _v = (fallback);				\
	const struct variable_value *_val;				\
	_val = config_get_value((config), (name));			\
	if (_val != NULL) {						\
		_v = _val->field;					\
	}								\
	_v;								\
})

struct config_step {
	const char	*name;

	union {
		const char		*path;
		struct variable_value	 val;
	} command;

	struct {
		unsigned int	parallel:1;
	} flags;
};

struct config	*config_alloc(const char *, const char *, struct arena_scope *,
    struct arena *);
void		 config_free(struct config *);
int		 config_parse(struct config *);
int		 config_append_var(struct config *, const char *);
int		 config_interpolate_file(struct config *, const char *);
const char	*config_interpolate_str(struct config *, const char *);
const char	*config_interpolate_lookup(const char *, struct arena_scope *,
    void *);

enum robsd_mode			 config_get_mode(const struct config *);
struct config_step		*config_get_steps(struct config *,
    unsigned int, struct arena_scope *);
const struct variable_value	*config_get_value(struct config *,
    const char *);
