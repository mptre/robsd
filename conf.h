#include "mode.h"

struct arena;
struct arena_scope;

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

struct variable_value {
	enum variable_type {
		INTEGER,
		STRING,
		DIRECTORY,
		LIST,
	} type;

	unsigned int    flags;
#define VARIABLE_VALUE_DIRTY

	union {
		const void	 *ptr;
		const char	 *str;
		char		**list;
		int		  integer;
	};
};

struct config	*config_alloc(const char *, const char *, struct arena_scope *,
    struct arena *);
void		 config_free(struct config *);
int		 config_parse(struct config *);
int		 config_append_var(struct config *, const char *);
int		 config_interpolate(struct config *);
const char	*config_interpolate_str(struct config *, const char *);
const char	*config_interpolate_lookup(const char *, struct arena_scope *,
    void *);

enum robsd_mode			  config_get_mode(const struct config *);
const char			**config_get_steps(struct config *);
const struct variable_value	 *config_get_value(struct config *,
    const char *);
