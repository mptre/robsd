struct variable_value {
	enum variable_type {
		INTEGER,
		STRING,
		DIRECTORY,
		LIST,
	} type;

	union {
		const void	 *ptr;
		char		 *str;
		char		**list;
		int		  integer;
	};
};

struct config	*config_alloc(const char *, const char *);
void		 config_free(struct config *);
int		 config_parse(struct config *);
int		 config_append_var(struct config *, const char *);
struct variable	*config_find(struct config *, const char *);
int		 config_interpolate(struct config *);
char		*config_interpolate_str(struct config *, const char *);
char		*config_interpolate_lookup(const char *, void *);

const struct variable_value *variable_get_value(const struct variable *);
