struct buffer;

struct step {
	char		*st_duration;
	char		*st_exit;
	char		*st_log;
	char		*st_name;
	char		*st_step;
	char		*st_time;
	char		*st_user;
	char		*st_skip;

	unsigned int	 st_id;
};

struct step	*steps_parse(const char *);
void		 steps_free(struct step *);
int		 steps_sort(struct step *);
struct step	*steps_find_by_name(struct step *, const char *);
void		 steps_header(struct buffer *);

char	*step_interpolate_lookup(const char *, void *);
int	 step_serialize(const struct step *, struct buffer *);
int	 step_set_defaults(struct step *);
int	 step_set_field(struct step *, const char *, const char *);
int	 step_set_keyval(struct step *, const char *);
