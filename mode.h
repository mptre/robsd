#ifndef MODE_H
#define MODE_H

#define FOR_ROBSD_MODES(OP)						\
	OP(ROBSD,	  "robsd")					\
	OP(ROBSD_CROSS,	  "robsd-cross")				\
	OP(ROBSD_PORTS,	  "robsd-ports")				\
	OP(ROBSD_REGRESS, "robsd-regress")				\
	OP(CANVAS,        "canvas")

enum robsd_mode {
#define OP(c, _) c,
	FOR_ROBSD_MODES(OP)
#undef OP
};

int		 robsd_mode_parse(const char *, enum robsd_mode *);
const char	*robsd_mode_str(enum robsd_mode);

#endif /* !MODE_H */
