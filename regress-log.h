struct buffer;

#define REGRESS_LOG_FAILED		0x00000001u
#define REGRESS_LOG_SKIPPED		0x00000002u
#define REGRESS_LOG_XFAILED		0x00000004u
#define REGRESS_LOG_XPASSED		0x00000008u
#define REGRESS_LOG_ERROR		0x00000010u
#define REGRESS_LOG_PEEK		0x00000020u

int	regress_log_parse(const char *, struct buffer *, unsigned int);
int	regress_log_peek(const char *, unsigned int);
int	regress_log_trim(const char *, struct buffer *);
