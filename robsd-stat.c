#ifdef __OpenBSD__

#include "config.h"

#include <sys/resource.h>
#include <sys/sched.h>
#include <sys/sysctl.h>

#include <err.h>
#include <inttypes.h>
#include <limits.h>
#include <pwd.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include "libks/arena.h"
#include "libks/vector.h"

struct stat_context {
	char		 directory[PATH_MAX];
	struct arena	*scratch;
	uint64_t	 time;
	double		 loadavg;
	int		 nprocs;
	int		 nthreads;
	struct {
		long	c_abs[CPUSTATES];
		double	c_rel[CPUSTATES];
	} cpu;
};

static void	usage(void) __attribute__((__noreturn__));

/* stat collect routines */
static int	stat_cpu(struct stat_context *);
static int	stat_directory(struct stat_context *, char **);
static int	stat_directory1(struct stat_context *, const char *);
static int	stat_loadavg(struct stat_context *);
static int	stat_procs_and_threads(struct stat_context *);
static int	stat_time(struct stat_context *);

static void	stat_print(const struct stat_context *, FILE *);

static int	cpustate(int);

int
main(int argc, char *argv[])
{
	VECTOR(char *) users;
	struct stat_context c;
	FILE *fh = stdout;
	unsigned int interval_s = 0;
	int doheader = 0;
	int error = 0;
	int ch;

	if (VECTOR_INIT(users))
		err(1, NULL);

	while ((ch = getopt(argc, argv, "Hi:u:")) != -1) {
		switch (ch) {
		case 'H':
			doheader = 1;
			break;
		case 'i': {
			const char *errstr;

			interval_s = strtonum(optarg, 1, INT_MAX, &errstr);
			if (interval_s == 0)
				errx(1, "interval %s %s", optarg, errstr);
			break;
		}
		case 'u': {
			char **dst;

			dst = VECTOR_ALLOC(users);
			if (dst == NULL)
				err(1, NULL);
			*dst = optarg;
			break;
		}
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;
	if (argc > 0 || (!doheader && interval_s == 0))
		usage();

	if (doheader) {
		/* Keep in sync with the robsd-stat.8 manual. */
		fprintf(fh, "time,load,user,sys,spin,intr,idle,nprocs,"
		    "nthreads,directory\n");
		VECTOR_FREE(users);
		return 0;
	}

	if (VECTOR_EMPTY(users))
		usage();

	/* Close common file descriptors since we want to act like a daemon. */
	close(0);

	memset(&c, 0, sizeof(c));
	c.scratch = arena_alloc();

	for (;;) {
		if (stat_time(&c) ||
		    stat_cpu(&c) ||
		    stat_loadavg(&c) ||
		    stat_procs_and_threads(&c) ||
		    stat_directory(&c, users)) {
			error = 1;
			break;
		}

		stat_print(&c, fh);
		usleep(interval_s * 1000 * 1000);
	}

	arena_free(c.scratch);
	VECTOR_FREE(users);

	return error;
}

static void
usage(void)
{
	fprintf(stderr, "usage: robsd-stat [-H] [-u user] -i interval\n");
	exit(1);
}

static int
stat_cpu(struct stat_context *c)
{
	int mib[2] = { CTL_KERN, KERN_CPTIME };
	int i;
	long cpu[CPUSTATES];
	long tot = 0;
	size_t len;

	len = sizeof(cpu);
	if (sysctl(mib, 2, &cpu, &len, NULL, 0) == -1) {
		warn("sysctl: kern.cp_time");
		return 1;
	}

	for (i = 0; i < CPUSTATES; i++) {
		if (c->cpu.c_abs[i] == 0)
			continue;
		tot += cpu[i] - c->cpu.c_abs[i];
	}

	memset(c->cpu.c_rel, 0, sizeof(c->cpu.c_rel));
	for (i = 0; i < CPUSTATES; i++) {
		double delta;

		if (c->cpu.c_abs[i] == 0)
			continue;

		delta = cpu[i] - c->cpu.c_abs[i];
		c->cpu.c_rel[cpustate(i)] += delta / tot;
	}

	memcpy(c->cpu.c_abs, cpu, sizeof(c->cpu.c_abs));
	return 0;
}

/*
 * Try to figure out in which directory the ongoing release build is currently
 * at by finding the make process started by the given user(s) with the longest
 * current working directory. A surprisingly accurate guess.
 */
static int
stat_directory(struct stat_context *c, char **users)
{
	size_t i;

	for (i = 0; i < VECTOR_LENGTH(users); i++) {
		switch (stat_directory1(c, users[i])) {
		case -1:
			return 1;
		case 0:
			continue;
		case 1:
			return 0;
		}
	}
	return 0;
}

static int
stat_directory1(struct stat_context *c, const char *user)
{
	int mib[6];
	struct kinfo_proc *kp;
	struct passwd *pw;
	size_t kpsiz = sizeof(struct kinfo_proc);
	size_t maxlen = 0;
	size_t siz = 0;
	unsigned int i, nprocs;

	arena_scope(c->scratch, s);

	c->directory[0] = '\0';

	pw = getpwnam(user);
	if (pw == NULL) {
		warnx("getpwnam: %s: no such user", user);
		return -1;
	}

	mib[0] = CTL_KERN;
	mib[1] = KERN_PROC;
	mib[2] = KERN_PROC_UID;
	mib[3] = (int)pw->pw_uid;
	mib[4] = (int)kpsiz;
	mib[5] = 0;

	if (sysctl(mib, 6, NULL, &siz, NULL, 0) == -1) {
		warn("sysctl: kern.proc.uid");
		return -1;
	}
	nprocs = siz / kpsiz;
	if (nprocs == 0)
		return 0;
	/* Cope with new processes, roughly 10% growth. */
	nprocs += nprocs / 8;
	kp = arena_calloc(&s, nprocs, sizeof(*kp));
	mib[5] = (int)(nprocs * kpsiz);
	if (sysctl(mib, 6, kp, &siz, NULL, 0) == -1) {
		warn("sysctl: kern.proc.uid");
		goto err;
	}
	nprocs = siz / kpsiz;
	if (nprocs == 0)
		goto out;

	for (i = 0; i < nprocs; i++) {
		char cwd[PATH_MAX];

		if (strcmp(kp[i].p_comm, "make") != 0 &&
		    strcmp(kp[i].p_comm, "gmake") != 0)
			continue;

		mib[0] = CTL_KERN;
		mib[1] = KERN_PROC_CWD;
		mib[2] = kp[i].p_pid;
		siz = sizeof(cwd);
		if (sysctl(mib, 3, &cwd, &siz, NULL, 0) == -1)
			continue;	/* process gone by now */
		if (siz > maxlen) {
			(void)strlcpy(c->directory, cwd,
			    sizeof(c->directory));
			maxlen = siz;
		}
	}

out:
	return maxlen > 0;

err:
	return -1;
}

static int
stat_loadavg(struct stat_context *c)
{
	int mib[2];
	int ncpu;
	struct loadavg lavg;
	size_t len;

	mib[0] = CTL_VM;
	mib[1] = VM_LOADAVG;
	len = sizeof(lavg);
	if (sysctl(mib, 2, &lavg, &len, NULL, 0) == -1) {
		warn("sysctl: vm.loadavg");
		return 1;
	}
	c->loadavg = (double)lavg.ldavg[0] / lavg.fscale;

	mib[0] = CTL_HW;
	mib[1] = HW_NCPUONLINE;
	len = sizeof(ncpu);
	if (sysctl(mib, 2, &ncpu, &len, NULL, 0) == -1) {
		warn("sysctl hw.ncpuonline");
		return 1;
	}
	c->loadavg /= ncpu;
	return 0;
}

static int
stat_procs_and_threads(struct stat_context *c)
{
	int mib[2];
	int nprocs, nthreads;
	size_t len;

	mib[0] = CTL_KERN;
	mib[1] = KERN_NPROCS;
	len = sizeof(nprocs);
	if (sysctl(mib, 2, &nprocs, &len, NULL, 0) == -1) {
		warn("sysctl: kern.nprocs");
		return 1;
	}
	c->nprocs = nprocs;

	mib[0] = CTL_KERN;
	mib[1] = KERN_NTHREADS;
	len = sizeof(nthreads);
	if (sysctl(mib, 2, &nthreads, &len, NULL, 0) == -1) {
		warn("sysctl: kern.nthreads");
		return 1;
	}
	c->nthreads = nthreads;

	return 0;
}

static int
stat_time(struct stat_context *c)
{
	struct timespec ts;

	if (clock_gettime(CLOCK_REALTIME, &ts) == -1) {
		warn("clock_gettime");
		return 1;
	}

	c->time = (uint64_t)(ts.tv_sec + ts.tv_nsec / 1000000000);
	return 0;
}

static void
stat_print(const struct stat_context *c, FILE *fh)
{
	fprintf(fh, "%" PRIu64 ",%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%d,%s\n",
	    c->time,
	    c->loadavg,
	    c->cpu.c_rel[CP_USER],
	    c->cpu.c_rel[CP_SYS],
	    c->cpu.c_rel[CP_SPIN],
	    c->cpu.c_rel[CP_INTR],
	    c->cpu.c_rel[CP_IDLE],
	    c->nprocs,
	    c->nthreads,
	    c->directory);
	fflush(fh);
}

/*
 * Translate CPU state, used to summarize user and nice.
 */
static int
cpustate(int state)
{
	switch (state) {
	case CP_NICE:
		return CP_USER;
	default:
		return state;
	}
}

#else

int
main(void)
{
	return 0;
}

#endif
