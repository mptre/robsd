#include <stdarg.h>

char	*ifgrinet(const char *);

void	log_warn(const char *, int, const char *, ...)
	__attribute__((format(printf, 3, 4)));
void	log_warnx(const char *, int, const char *, ...)
	__attribute__((format(printf, 3, 4)));
void	logv(void (*)(const char *, ...), const char *, int, const char *,
    va_list);
