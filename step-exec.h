struct arena;
struct config;

/* Timeout exit code, borrowed from timeout(1). */
#define EX_TIMEOUT		124

#define STEP_EXEC_TRACE		0x00000001u
#define STEP_EXEC_TIMEOUT	0x00000002u

int	step_exec(const char *, struct config *, struct arena *, unsigned int);
