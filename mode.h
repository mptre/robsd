#ifndef MODE_H
#define MODE_H

enum robsd_mode {
	CONFIG_ROBSD,
	CONFIG_ROBSD_CROSS,
	CONFIG_ROBSD_PORTS,
	CONFIG_ROBSD_REGRESS,
};

int		 robsd_mode_parse(const char *, enum robsd_mode *);
const char	*robsd_mode_str(enum robsd_mode);

#endif
