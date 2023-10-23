#include "mode.h"

struct arena;
struct arena_scope;

#define config_find_value(config, name, field) __extension__ ({		\
	struct variable_value *_val;					\
	typeof(_val->field) _v = 0;					\
	const struct variable *_va = config_find((config), (name));	\
	if (_va != NULL) {						\
		_v = variable_get_value(_va)->field;			\
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
struct variable	*config_find(struct config *, const char *);
int		 config_interpolate(struct config *);
char		*config_interpolate_str(struct config *, const char *);
const char	*config_interpolate_lookup(const char *, struct arena_scope *,
    void *);

enum robsd_mode	  config_get_mode(const struct config *);
const char	**config_get_steps(struct config *);

const struct variable_value *variable_get_value(const struct variable *);
