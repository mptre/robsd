struct buffer;

struct step {
	struct step_field	*st_fields;
};

struct step	*steps_parse(const char *);
void		 steps_free(struct step *);
void		 steps_sort(struct step *);
struct step	*steps_find_by_name(struct step *, const char *);
struct step	*steps_find_by_id(struct step *, int);
void		 steps_header(struct buffer *);

int	 step_init(struct step *, int);
char	*step_interpolate_lookup(const char *, void *);
int	 step_serialize(const struct step *, struct buffer *);
int	 step_set_keyval(struct step *, const char *);
