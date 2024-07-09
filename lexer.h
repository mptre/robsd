struct lexer;
struct token;

#define LEXER_EOF	0x7fffffff

struct lexer_arg {
	const char	*path;

	struct {
		struct arena_scope	*eternal_scope;
	} arena;

	struct {
		/*
		 * Read callback with the following semantics:
		 *
		 *     1. In case of encountering an error, NULL must be
		 *        returned.
		 *     2. Signalling the reach of end of file is done by
		 *        returning a token with type LEXER_EOF.
		 *     3. If none of the above occurs, the next consumed token
		 *        is assumed to be returned.
		 */
		struct token	*(*read)(struct lexer *, void *);

		/*
		 * Serialize routine used to turn the given token into something
		 * human readable.
		 */
		const char	*(*serialize)(const struct token *);

		/* Opaque argument passed to callbacks. */
		void		*arg;
	} callbacks;
};

struct lexer_state {
	int	lno;
};

struct lexer	*lexer_alloc(const struct lexer_arg *);

struct token	*lexer_emit(struct lexer *, const struct lexer_state *, int);
int		 lexer_getc(struct lexer *, char *);
void		 lexer_ungetc(struct lexer *, char);

int	lexer_back(struct lexer *, struct token **);
int	lexer_next(struct lexer *, struct token **);
int	lexer_expect(struct lexer *, int, struct token **);
int	lexer_peek(struct lexer *, int);
int	lexer_if(struct lexer *, int, struct token **);

int			lexer_get_error(const struct lexer *);
struct lexer_state	lexer_get_state(const struct lexer *);

void	lexer_warn(struct lexer *, int, const char *, ...)
	__attribute__((format(printf, 3, 4)));
void	lexer_warnx(struct lexer *, int, const char *, ...)
	__attribute__((format(printf, 3, 4)));
