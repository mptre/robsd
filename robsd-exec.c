#include "config.h"

#include <sys/wait.h>

#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static __dead void	usage(void);

static int	exitstatus(int);
static int	waiteof(int, int);
static int	killwaitpg(int, int, int *);
static int	killwaitpg1(int, int, int, int *);
static void	siginstall(int, void (*)(int), int);
static void	sighandler(int);

static volatile sig_atomic_t	gotsig;

int
main(int argc, char *argv[])
{
	pid_t pid;
	int pip[2];
	int error, status;

	if (argc < 2)
		usage();

	if (pledge("stdio proc exec", NULL) == -1)
		err(1, "pledge");

	/* NOLINTNEXTLINE(android-cloexec-pipe2) */
	if (pipe2(pip, O_NONBLOCK) == -1)
		err(1, "pipe2");

	pid = fork();
	if (pid == -1)
		err(1, "fork");
	if (pid == 0) {
		close(pip[0]);
		if (setsid() == -1)
			err(1, "setsid");

		/* Unblock common signals. */
		siginstall(SIGHUP, SIG_DFL, 0);
		siginstall(SIGINT, SIG_DFL, 0);
		siginstall(SIGQUIT, SIG_DFL, 0);

		/* Signal to the parent that the process group is present. */
		close(pip[1]);
		execvp(argv[1], &argv[1]);
		err(1, "%s", argv[1]);
	}

	siginstall(SIGPIPE, SIG_IGN, 0);
	siginstall(SIGTERM, sighandler, ~SA_RESTART);

	/* Wait for the process group to become present. */
	close(pip[1]);
	if (waiteof(pip[0], 1000)) {
		warnx("process group failure");
		if (waitpid(pid, &status, 0) == -1)
			return 1;
		return exitstatus(status);
	}
	close(pip[0]);

	if (waitpid(-pid, &status, 0) == -1) {
		if (gotsig) {
			warnx("caught signal, kill process group ...");
			if (killwaitpg(pid, 5000, &status))
				warnx("failed to kill process group");
		} else {
			err(1, "waitpid");
		}
	}
	error = exitstatus(status);
	if (error)
		warnx("process group exited %d", error);
	return error;
}

static __dead void
usage(void)
{
	fprintf(stderr, "usage: robsd-exec utility [argument ...]\n");
	exit(1);
}

static int
exitstatus(int status)
{
	if (WIFEXITED(status))
		return WEXITSTATUS(status);
	if (WIFSIGNALED(status))
		return 128 + WTERMSIG(status);
	return 1;
}

static int
waiteof(int fd, int timoms)
{
	unsigned int slpms = 1;

	for (;;) {
		char buf[1];
		ssize_t n;

		n = read(fd, buf, sizeof(buf));
		if (n == -1) {
			if (errno == EAGAIN) {
				usleep(slpms * 1000);
				timoms -= slpms;
				if (timoms <= 0)
					return 1;
			} else {
				warn("read");
				return 1;
			}
		} else if (n == 0) {
			break;
		}
	}
	return 0;
}

static int
killwaitpg(int pgid, int timoms, int *status)
{
	warnx("sending term signal ...");
	if (killwaitpg1(pgid, SIGTERM, timoms, status) == 0)
		return 0;
	warnx("sending kill signal ...");
	if (killwaitpg1(pgid, SIGKILL, timoms, status) == 0)
		return 0;

	*status = 1;
	return 1;
}

static int
killwaitpg1(int pgid, int signo, int timoms, int *status)
{
	unsigned int slpms = 100;

	if (kill(-pgid, signo) == -1)
		err(1, "kill");

	for (;;) {
		int w;

		w = waitpid(-pgid, status, WNOHANG);
		if (w == -1) {
			warn("waitpid");
			return 1;
		}
		if (w == 0) {
			usleep(slpms * 1000);
			timoms -= slpms;
			if (timoms <= 0)
				return 1;
			continue;
		}

		return 0;
	}
}

static void
siginstall(int signo, void (*handler)(int), int rmflags)
{
	struct sigaction sa;

	if (sigaction(signo, NULL, &sa) == -1)
		err(1, "sigaction");
	sa.sa_handler = handler;
	if (rmflags)
		sa.sa_flags &= rmflags;
	if (sigaction(signo, &sa, NULL) == -1)
		err(1, "sigaction");
}

static void
sighandler(int signo)
{
	gotsig = signo;
}
