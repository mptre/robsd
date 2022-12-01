#include <stdint.h>	/* int64_t */

struct buffer;

struct step {
	struct step_field	*st_fields;
};

union step_value {
	char	*str;
	int64_t	 integer;
};

struct step	*steps_parse(const char *);
void		 steps_free(struct step *);
void		 steps_sort(struct step *);
struct step	*steps_find_by_name(struct step *, const char *);
struct step	*steps_find_by_id(struct step *, int);
void		 steps_header(struct buffer *);

int			 step_init(struct step *);
char			*step_interpolate_lookup(const char *, void *);
int			 step_serialize(const struct step *, struct buffer *);
const union step_value	*step_get_field(const struct step *, const char *);
int			 step_set_keyval(struct step *, const char *);
int			 step_set_field_integer(struct step *, const char *,
    int);
