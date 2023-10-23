struct buffer;
struct arena_scope;

struct interpolate_arg {
	/*
	 * Callback used to resolve a referenced variable into its corresponding
	 * value. Returning NULL indicates that the variable is absent.
	 */
	const char	*(*lookup)(const char *, struct arena_scope *, void *);

	/* Opaque argument passed to callbacks. */
	void		*arg;

	struct arena	*scratch;
	int		 lno;
	unsigned int	 flags;
#define INTERPOLATE_IGNORE_LOOKUP_ERRORS	0x00000001u
};

char	*interpolate_file(const char *, const struct interpolate_arg *);
char	*interpolate_str(const char *, const struct interpolate_arg *);

int	interpolate_buffer(const char *, struct buffer *,
    const struct interpolate_arg *);
