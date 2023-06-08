#define CONCAT_INNER(a, b) a ## b
#define CONCAT(a, b) CONCAT_INNER(a, b)
#define NODE() CONCAT(node, __LINE__)

#define HTML_HEAD(html)							\
	for (int NODE() = html_head_enter((html));			\
	    NODE();							\
	    NODE() = html_head_leave((html)))

#define HTML_NODE(html, type)						\
	for (int NODE() = html_node_enter((html), (type), &html_attr_last);\
	    NODE();							\
	    NODE() = html_node_leave((html), (type)))

#define HTML_NODE_ATTR(html, type, ...)					\
	for (int NODE() = html_node_enter((html), (type), __VA_ARGS__, &html_attr_last);\
	    NODE();							\
	    NODE() = html_node_leave((html), (type)))

#define HTML_ATTR(k, v) &(struct html_attribute){.key = (k), .val = (v)}

#define HTML_TEXT(html, str) \
	html_text((html), (str))

struct html_attribute {
	const char	*key;
	const char	*val;
};

struct html	*html_alloc(void);
void		 html_free(struct html *);

int	html_write(const struct html *, const char *);

int	html_head_enter(struct html *);
int	html_head_leave(struct html *);

int	html_node_enter(struct html *, const char *, ...);
int	html_node_leave(struct html *, const char *);
void	html_text(struct html *, const char *);

extern struct html_attribute	html_attr_last;
