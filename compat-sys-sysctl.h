#include "config.h"

extern int unused;

#ifndef HAVE_SYS_SYSCTL_H

#include "cdefs.h"

enum {
	CTL_HW,
	HW_NCPUONLINE,
};

enum {
	CTL_KERN,
	KERN_CPTIME,
	KERN_PROC,
	KERN_PROC_CWD,
	KERN_PROC_UID,
};

enum {
	CTL_VM,
	VM_LOADAVG,
};

struct kinfo_proc {
	const char *p_comm;
	int p_pid;
};

struct loadavg {
	int ldavg[1];
	int fscale;
};

static inline int
sysctl(const int *UNUSED(name), u_int UNUSED(namelen), void *UNUSED(oldp),
    size_t *UNUSED(oldlenp), void *UNUSED(newp), size_t UNUSED(newlen))
{
	return -1;
}

#endif
