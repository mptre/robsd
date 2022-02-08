#include <sys/queue.h>

#include <stdarg.h>

#define UNUSED(x)	_##x __attribute__((__unused__))

/*
 * config -------------------------------------------------------------------------
 */

struct config	*config_parse(const char *);
void		 config_free(struct config *);
int		 config_validate(const struct config *);
int		 config_interpolate(const struct config *);

/*
 * log -------------------------------------------------------------------------
 */
void	log_warnx(const char *, int, const char *, ...)
	__attribute__((format(printf, 3, 4)));
void	logv(void (*)(const char *, ...), const char *, int, const char *,
    va_list);

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
void			 strings_append(struct string_list *, char *);
