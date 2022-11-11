#include <sys/queue.h>

#include <stddef.h>

/*
 * config -------------------------------------------------------------------------
 */

struct config	*config_alloc(const char *);
void		 config_free(struct config *);
void		 config_set_path(struct config *, const char *);
int		 config_parse(struct config *);
int		 config_append_var(struct config *, const char *);
int		 config_append_string(struct config *, const char *,
    const char *);
struct variable	*config_find(struct config *, const char *);
int		 config_interpolate(struct config *);
char		*config_interpolate_str(const struct config *,
    const char *, const char *, int);

const struct string_list *variable_list(const struct variable *);

/*
 * strings ---------------------------------------------------------------------
 */

struct string {
	char			*st_val;
	TAILQ_ENTRY(string)	 st_entry;
};

TAILQ_HEAD(string_list, string);

struct string_list	*strings_alloc(void);
void			 strings_free(struct string_list *);
void			 strings_append(struct string_list *, const char *);
void			 strings_concat(struct string_list *,
    struct string_list *);
unsigned int		 strings_len(const struct string_list *);
