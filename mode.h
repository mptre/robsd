#ifndef MODE_H
#define MODE_H

enum robsd_mode {
	ROBSD,
	ROBSD_CROSS,
	ROBSD_PORTS,
	ROBSD_REGRESS,
};

int		 robsd_mode_parse(const char *, enum robsd_mode *);
const char	*robsd_mode_str(enum robsd_mode);

#endif
