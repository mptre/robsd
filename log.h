#include <stdarg.h>

void	log_disable(void);

void	log_warnx(const char *, int, const char *, ...)
	__attribute__((format(printf, 3, 4)));
void	log_vwarnx(const char *, int, const char *, va_list)
	__attribute__((format(printf, 3, 0)));
