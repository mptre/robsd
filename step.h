#include <stdint.h>	/* int64_t */

#include "mode.h"

struct arena;
struct buffer;

struct step {
	struct step_field	*st_fields;
};

union step_value {
	char	*str;
	int64_t	 integer;
};

struct step_file	*steps_parse(const char *);
void			 steps_free(struct step_file *);
struct step		*steps_get(struct step_file *);
struct step		*steps_alloc(struct step_file *);
int64_t			 steps_total_duration(const struct step_file *,
    enum robsd_mode);

void		 steps_sort(struct step *);
struct step	*steps_find_by_name(struct step *, const char *);
struct step	*steps_find_by_id(struct step *, int);
void		 steps_header(struct buffer *);

int			 step_init(struct step *);
char			*step_interpolate_lookup(const char *, void *);
int			 step_serialize(const struct step *, struct buffer *,
    struct arena *);
const union step_value	*step_get_field(const struct step *, const char *);
int			 step_set_keyval(struct step *, const char *);
int			 step_set_field_integer(struct step *, const char *,
    int64_t);
