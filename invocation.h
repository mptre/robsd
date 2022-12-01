struct invocation	*invocation_alloc(const char *, const char *);
void			 invocation_free(struct invocation *);
const char		*invocation_walk(struct invocation *);
