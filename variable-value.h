#ifndef VARIABLE_VALUE_H
#define VARIABLE_VALUE_H

struct variable_value {
	enum variable_type {
		INTEGER,
		STRING,
		DIRECTORY,
		LIST,
	} type;

	union {
		const void	 *ptr;
		const char	 *str;
		char		**list;
		int		  integer;
	};
};

#endif
