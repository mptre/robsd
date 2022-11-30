struct config;

struct invocation	*invocation_alloc(const struct config *);
void			 invocation_free(struct invocation *);
const char		*invocation_walk(struct invocation *);
