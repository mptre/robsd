struct buffer;

void	regress_log_init(void);
void	regress_log_shutdown(void);

#define REGRESS_LOG_FAILED	0x00000001u
#define REGRESS_LOG_SKIPPED	0x00000002u
#define REGRESS_LOG_ERROR	0x00000004u

int	regress_log_parse(const char *, struct buffer *, unsigned int);
