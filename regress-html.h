struct arena_scope;

struct regress_html	*regress_html_alloc(const char *, struct arena_scope *);
void			 regress_html_free(struct regress_html *);

int	regress_html_parse(struct regress_html *, const char *, const char *);
int	regress_html_render(struct regress_html *);
