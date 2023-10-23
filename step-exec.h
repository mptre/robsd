struct arena;
struct config;

#define STEP_EXEC_TRACE		0x00000001u

int	step_exec(const char *, struct config *, struct arena *, unsigned int);
