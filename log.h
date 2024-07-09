#include <stdarg.h>

enum log_func {
	LOG_WARN,
	LOG_WARNX,
};

void	log_disable(void);

void	log_warnx(const char *, int, const char *, ...)
	__attribute__((format(printf, 3, 4)));

void	logv(enum log_func, const char *, int, const char *, va_list);
