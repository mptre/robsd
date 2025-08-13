struct arena;
struct arena_scope;

struct regress_html *regress_html_alloc(const char *, struct arena *,
    struct arena_scope *);
int regress_html_parse(struct regress_html *, const char *, const char *);
int regress_html_render(struct regress_html *);
