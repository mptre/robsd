struct interpolate_arg {
	/*
	 * Callback used to resolve a referenced variable into its corresponding
	 * value. The returned value must be heap allocated. Returning NULL
	 * indicates that the variable is absent.
	 */
	char	*(*lookup)(const char *, void *);

	/* Opaque argument passed to callbacks. */
	void	*arg;

	int	 lno;
};

char	*interpolate_file(const char *, const struct interpolate_arg *);
char	*interpolate_str(const char *, const struct interpolate_arg *);
