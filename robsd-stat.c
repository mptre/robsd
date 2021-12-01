#include <sys/types.h>
#include <sys/resource.h>
#include <sys/sched.h>
#include <sys/sysctl.h>

#include <err.h>
#include <inttypes.h>
#include <limits.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

struct robsd_stat {
	char		rs_directory[PATH_MAX];
	uint64_t	rs_time;
	double		rs_loadavg;
	struct {
		long	c_abs[CPUSTATES];
		double	c_rel[CPUSTATES];
	} rs_cpu;
};

static __dead void	usage(void);

/* stat collect routines */
static void	stat_cpu(struct robsd_stat *);
static void	stat_directory(struct robsd_stat *);
static void	stat_loadavg(struct robsd_stat *);
static void	stat_time(struct robsd_stat *);

static void	stat_print(const struct robsd_stat *, FILE *);

static int	cpustate(int);

int
main(int argc, char *argv[])
{
	struct robsd_stat rs;
	FILE *fh = stdout;
	int ch;
	int doheader = 0;
	int tick_s = 10;

	while ((ch = getopt(argc, argv, "H")) != -1) {
		switch (ch) {
		case 'H':
			doheader = 1;
			break;
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;
	if (argc > 0)
		usage();

	if (doheader) {
		/* Keep in sync with the robsd-stat.8 manual. */
		fprintf(fh, "time,load,user,sys,spin,intr,idle,directory\n");
		return 0;
	}

	memset(&rs, 0, sizeof(rs));
	for (;;) {
		stat_time(&rs);
		stat_cpu(&rs);
		stat_loadavg(&rs);
		stat_directory(&rs);
		stat_print(&rs, fh);
		usleep(tick_s * 1000 * 1000);
	}

	return 0;
}

static __dead void
usage(void)
{
	fprintf(stderr, "usage: robsd-stat [-H]\n");
	exit(1);
}

static void
stat_cpu(struct robsd_stat *rs)
{
	int mib[2] = { CTL_KERN, KERN_CPTIME };
	long cpu[CPUSTATES];
	long tot = 0;
	size_t len;
	int i;

	len = sizeof(cpu);
	if (sysctl(mib, 2, &cpu, &len, NULL, 0) == -1)
		err(1, "sysctl: kern.cp_time");

	for (i = 0; i < CPUSTATES; i++) {
		if (rs->rs_cpu.c_abs[i] == 0)
			continue;
		tot += cpu[i] - rs->rs_cpu.c_abs[i];
	}

	memset(rs->rs_cpu.c_rel, 0, sizeof(rs->rs_cpu.c_rel));
	for (i = 0; i < CPUSTATES; i++) {
		double delta;

		if (rs->rs_cpu.c_abs[i] == 0)
			continue;

		delta = cpu[i] - rs->rs_cpu.c_abs[i];
		rs->rs_cpu.c_rel[cpustate(i)] += delta / tot;
	}

	memcpy(rs->rs_cpu.c_abs, cpu, sizeof(rs->rs_cpu.c_abs));
}

/*
 * Try to figure out in which directory the ongoing release build is currently
 * at by finding the make process started by the build user with the longest
 * current working directory. A surprisingly accurate guess.
 */
static void
stat_directory(struct robsd_stat *rs)
{
	int mib[6];
	struct kinfo_proc *kp;
	size_t kpsiz = sizeof(struct kinfo_proc);
	size_t maxlen = 0;
	size_t siz = 0;
	struct passwd *pw;
	int i, nprocs;

	rs->rs_directory[0] = '\0';

	pw = getpwnam("build");
	if (pw == NULL)
		errx(1, "getpwnam: failed to lookup build user");

	mib[0] = CTL_KERN;
	mib[1] = KERN_PROC;
	mib[2] = KERN_PROC_UID;
	mib[3] = pw->pw_uid;
	mib[4] = kpsiz;
	mib[5] = 0;

	if (sysctl(mib, 6, NULL, &siz, NULL, 0) == -1)
		err(1, "sysctl: kern.proc.uid");
	nprocs = siz / kpsiz;
	if (nprocs == 0)
		return;
	/* Cope with new processes, roughly 10% growth. */
	nprocs += nprocs / 8;
	kp = calloc(nprocs, sizeof(*kp));
	if (kp == NULL)
		err(1, NULL);
	mib[5] = nprocs * kpsiz;
	if (sysctl(mib, 6, kp, &siz, NULL, 0) == -1)
		err(1, "sysctl: kern.proc.uid");
	nprocs = siz / kpsiz;
	if (nprocs == 0)
		goto out;

	for (i = 0; i < nprocs; i++) {
		char cwd[PATH_MAX];

		if (strcmp(kp[i].p_comm, "make"))
			continue;

		mib[0] = CTL_KERN;
		mib[1] = KERN_PROC_CWD;
		mib[2] = kp[i].p_pid;
		siz = sizeof(cwd);
		if (sysctl(mib, 3, &cwd, &siz, NULL, 0) == -1)
			continue;	/* process gone by now */
		if (siz > maxlen) {
			(void)strlcpy(rs->rs_directory, cwd,
			    sizeof(rs->rs_directory));
			maxlen = siz;
		}
	}

out:
	free(kp);
}

static void
stat_loadavg(struct robsd_stat *rs)
{
	int mib[2];
	struct loadavg lavg;
	size_t len;
	int ncpu;

	mib[0] = CTL_VM;
	mib[1] = VM_LOADAVG;
	len = sizeof(lavg);
	if (sysctl(mib, 2, &lavg, &len, NULL, 0) == -1)
		err(1, "sysctl: vm.loadavg");
	rs->rs_loadavg = (double)lavg.ldavg[0] / lavg.fscale;

	mib[0] = CTL_HW;
	mib[1] = HW_NCPUONLINE;
	len = sizeof(ncpu);
	if (sysctl(mib, 2, &ncpu, &len, NULL, 0) == -1)
		err(1, "sysctl hw.ncpuonline");
	rs->rs_loadavg /= ncpu;
}

static void
stat_time(struct robsd_stat *rs)
{
	struct timespec ts;

	if (clock_gettime(CLOCK_REALTIME, &ts) == -1)
		err(1, "clock_gettime");
	rs->rs_time = ts.tv_sec + ts.tv_nsec / 1000000000;
}

static void
stat_print(const struct robsd_stat *rs, FILE *fh)
{
	fprintf(fh, "%" PRIu64 ",%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%s\n",
	    rs->rs_time,
	    rs->rs_loadavg,
	    rs->rs_cpu.c_rel[CP_USER],
	    rs->rs_cpu.c_rel[CP_SYS],
	    rs->rs_cpu.c_rel[CP_SPIN],
	    rs->rs_cpu.c_rel[CP_INTR],
	    rs->rs_cpu.c_rel[CP_IDLE],
	    rs->rs_directory);
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
