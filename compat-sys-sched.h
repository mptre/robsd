#include "config.h"

extern int unused;

#ifndef HAVE_SYS_SCHED_H

enum {
	CP_USER,
	CP_NICE,
	CP_SYS,
	CP_SPIN,
	CP_INTR,
	CP_IDLE,
	CPUSTATES,
};

#endif
