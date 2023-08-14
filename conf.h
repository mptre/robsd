enum robsd_mode {
	CONFIG_ROBSD,
	CONFIG_ROBSD_CROSS,
	CONFIG_ROBSD_PORTS,
	CONFIG_ROBSD_REGRESS,
};

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

enum robsd_mode	 config_get_mode(const struct config *);
const char	*robsd_mode_str(enum robsd_mode);

const struct variable_value *variable_get_value(const struct variable *);
