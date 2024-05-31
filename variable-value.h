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

void	variable_value_init(struct variable_value *, enum variable_type);
void	variable_value_clear(struct variable_value *);
void	variable_value_append(struct variable_value *, const char *);
void	variable_value_concat(struct variable_value *, struct variable_value *);

#endif
