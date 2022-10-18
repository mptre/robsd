struct lexer;
struct token;

#define LEXER_EOF	0x7fffffff

struct lexer_arg {
	const char	*path;
	struct {
		int		 (*read)(struct lexer *, struct token *, void *);
		const char	*(*serialize)(int);
		void		*arg;
	} callbacks;
};

struct lexer	*lexer_alloc(const struct lexer_arg *);
void		 lexer_free(struct lexer *);

int	lexer_getc(struct lexer *, char *);
void	lexer_ungetc(struct lexer *, char);
int	lexer_next(struct lexer *, struct token **);
int	lexer_expect(struct lexer *, int, struct token **);
int	lexer_peek(struct lexer *, int);
int	lexer_if(struct lexer *, int, struct token **);

int	lexer_get_error(const struct lexer *);
int	lexer_get_lno(const struct lexer *);

void	lexer_warn(struct lexer *, int, const char *, ...)
	__attribute__((format(printf, 3, 4)));
void	lexer_warnx(struct lexer *, int, const char *, ...)
	__attribute__((format(printf, 3, 4)));
