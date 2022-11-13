union variable_value {
	const void	 *ptr;
	char		 *str;
	char		**list;
	int		  integer;
};

struct config	*config_alloc(const char *);
void		 config_free(struct config *);
void		 config_set_path(struct config *, const char *);
int		 config_parse(struct config *);
int		 config_append_var(struct config *, const char *);
int		 config_append_string(struct config *, const char *,
    const char *);
struct variable	*config_find(const struct config *, const char *);
int		 config_interpolate(struct config *);
char		*config_interpolate_str(const struct config *,
    const char *, const char *, int);

const union variable_value *variable_get_value(const struct variable *);
