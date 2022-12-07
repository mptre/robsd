struct invocation_state	*invocation_alloc(const char *, const char *);
void			 invocation_free(struct invocation_state *);
const char		*invocation_walk(struct invocation_state *);
