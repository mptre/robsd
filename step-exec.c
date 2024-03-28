#include "step-exec.h"

#include "config.h"

#include <sys/stat.h>
#include <sys/wait.h>

#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <unistd.h>

#include "libks/arena.h"

#include "conf.h"
#include "mode.h"

#define SIG_NO_RESTART	1

struct step_context {
	struct config		*config;
	struct arena		*scratch;
	unsigned int		 flags;
};

static int	exitstatus(int);
static int	waiteof(int, int);
static int	killwaitpg(int, int, int *);
static int	killwaitpg1(int, int, int, int *);
static void	siginstall(int, void (*)(int), int);
static void	sighandler(int);

static int	step_fork(struct step_context *, const char *, const char *,
    pid_t *);
static int	step_timeout(struct step_context *);

static const char	*resolve_step_script(struct step_context *,
    const char *);

static volatile sig_atomic_t	gotsig;

int
step_exec(const char *step_name, struct config *config, struct arena *scratch,
    unsigned int flags)
{
	struct step_context c = {
		.config		= config,
		.scratch	= scratch,
		.flags		= flags,
	};
	const char *step_script;
	pid_t pid;
	int error, status;

	step_script = resolve_step_script(&c, step_name);
	if (step_script == NULL) {
		warnx("%s: step script not found", step_name);
		return 1;
	}

	error = step_fork(&c, step_name, step_script, &pid);
	if (error)
		return error;
	if (waitpid(-pid, &status, 0) == -1) {
		if (gotsig) {
			warnx("caught signal %d, kill process group ...",
			    gotsig);
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
				timoms -= (int)slpms;
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
			timoms -= (int)slpms;
			if (timoms <= 0)
				return 1;
			continue;
		}

		return 0;
	}
}

static void
siginstall(int signo, void (*handler)(int), int restart)
{
	struct sigaction sa;

	if (sigaction(signo, NULL, &sa) == -1)
		err(1, "sigaction");
	sa.sa_handler = handler;
	if (restart == SIG_NO_RESTART)
		sa.sa_flags &= ~SA_RESTART;
	if (sigaction(signo, &sa, NULL) == -1)
		err(1, "sigaction");
}

static void
sighandler(int signo)
{
	gotsig = signo;
}

static int
step_fork(struct step_context *c, const char *step_name,
    const char *step_script, pid_t *out)
{
	int proc_pipe[2];
	int status, timeout;
	pid_t pid;

	/* NOLINTNEXTLINE(android-cloexec-pipe2) */
	if (pipe2(proc_pipe, O_NONBLOCK) == -1)
		err(1, "pipe2");

	pid = fork();
	if (pid == -1)
		err(1, "fork");
	if (pid == 0) {
		const char *argv[7];
		int argc = 0;

		argv[argc++] = "sh";
		argv[argc++] = "-eu";
		if (c->flags & STEP_EXEC_TRACE)
			argv[argc++] = "-x";
		argv[argc++] = step_script;
		argv[argc++] = step_name;
		argv[argc++] = NULL;

		close(proc_pipe[0]);
		if (setsid() == -1)
			err(1, "setsid");

		/* Unblock common signals. */
		siginstall(SIGHUP, SIG_DFL, 0);
		siginstall(SIGINT, SIG_DFL, 0);
		siginstall(SIGQUIT, SIG_DFL, 0);

		/* Signal to the parent that the process group is present. */
		close(proc_pipe[1]);
		execvp(argv[0], (char *const *)argv);
		err(1, "%s", argv[0]);
	}

	siginstall(SIGPIPE, SIG_IGN, 0);
	siginstall(SIGTERM, sighandler, SIG_NO_RESTART);

	/* Wait for the process group to become present. */
	close(proc_pipe[1]);
	if (waiteof(proc_pipe[0], 1000)) {
		int error;

		warnx("process group failure");
		if (waitpid(pid, &status, 0) == -1)
			return 1;
		error = exitstatus(status);
		return error ? error : 1;
	}
	close(proc_pipe[0]);

	timeout = step_timeout(c);
	if (timeout > 0) {
		siginstall(SIGALRM, sighandler, 0);
		alarm((unsigned int)timeout);
	}

	*out = pid;
	return 0;
}

static int
step_timeout(struct step_context *c)
{
	if (config_get_mode(c->config) != ROBSD_REGRESS)
		return 0;
	return config_value(c->config, "regress-timeout", integer, 0);
}

static const char *
resolve_step_script(struct step_context *c, const char *step_name)
{
	struct stat st;
	const char *step_script, *template;
	enum robsd_mode mode = config_get_mode(c->config);

	arena_scope(c->scratch, s);

	/* Give mode specific step script higher precedence. */
	template = arena_sprintf(&s, "${exec-dir}/%s-%s.sh",
	    robsd_mode_str(mode), step_name);
	step_script = config_interpolate_str(c->config, template);
	if (step_script == NULL)
		return NULL;
	if (stat(step_script, &st) == 0 && S_ISREG(st.st_mode))
		return step_script;

	/* Fallback to robsd step script. */
	template = arena_sprintf(&s, "${exec-dir}/robsd-%s.sh", step_name);
	step_script = config_interpolate_str(c->config, template);
	if (step_script == NULL)
		return NULL;
	if (stat(step_script, &st) == 0 && S_ISREG(st.st_mode))
		return step_script;

	if (mode == ROBSD_REGRESS) {
		/* Assume regress test step. */
		template = arena_sprintf(&s, "${exec-dir}/%s-exec.sh",
		    robsd_mode_str(mode));
		return config_interpolate_str(c->config, template);
	}

	return NULL;
}
