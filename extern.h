#include <sys/queue.h>

#include <stdarg.h>

#define UNUSED(x)	_##x __attribute__((__unused__))

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
 * log -------------------------------------------------------------------------
 */
void	log_warn(const char *, int, const char *, ...)
	__attribute__((format(printf, 3, 4)));
void	log_warnx(const char *, int, const char *, ...)
	__attribute__((format(printf, 3, 4)));
void	logv(void (*)(const char *, ...), const char *, int, const char *,
    va_list);

/*
 * buffer ----------------------------------------------------------------------
 */

struct buffer {
	char	*bf_ptr;
	size_t	 bf_siz;
	size_t	 bf_len;
};

struct buffer	*buffer_alloc(size_t);
struct buffer	*buffer_read(const char *);
void		 buffer_free(struct buffer *);
void		 buffer_append(struct buffer *, const char *, size_t);
void		 buffer_appendc(struct buffer *, char);
void		 buffer_appendv(struct buffer *, const char *, ...)
	__attribute__((__format__(printf, 2, 3)));
char		*buffer_release(struct buffer *);
void		 buffer_reset(struct buffer *);
int		 buffer_cmp(const struct buffer *, const struct buffer *);

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

/*
 * util ------------------------------------------------------------------------
 */

char	*ifgrinet(const char *);
