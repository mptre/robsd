#ifdef __OpenBSD__

#include "config.h"

#include <sys/types.h>
#include <sys/event.h>
#include <sys/time.h>

#include <err.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "libks/map.h"
#include "libks/vector.h"

struct context {
	MAP(int,, int)	pids;

	struct {
		VECTOR(struct kevent)	changes;
		VECTOR(struct kevent)	events;
	} kqueue;
};

static void	usage(void) __attribute__((__noreturn__));

static void	context_free(struct context *);
static void	kqueue_setup(struct context *);
static int	kqueue_handle_events(struct context *, int);
static int	parse_pids(struct context *, int, char **);
static int	pid_count(struct context *);

int
main(int argc, char *argv[])
{
	struct context ctx = {0};
	struct map_iterator it = {0};
	int *pid;
	int waitall = 0;
	int error = 0;
	int kq = -1;
	int ch, nevents, npids;

	while ((ch = getopt(argc, argv, "a")) != -1) {
		switch (ch) {
		case 'a':
			waitall = 1;
			break;
		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;
	if (argc == 0)
		usage();

	if (parse_pids(&ctx, argc, argv)) {
		error = 1;
		goto out;
	}

	kq = kqueue();
	if (kq == -1) {
		warn("kqueue");
		error = 1;
		goto out;
	}
	kqueue_setup(&ctx);

	npids = pid_count(&ctx);
	nevents = kevent(kq, ctx.kqueue.changes, npids,
	    ctx.kqueue.events, npids, NULL);
	if (nevents == -1) {
		warn("kevent");
		error = 1;
		goto out;
	}
	error = kqueue_handle_events(&ctx, nevents);
	if (error)
		goto out;

	while (waitall && pid_count(&ctx) > 0) {
		nevents = kevent(kq, NULL, 0, ctx.kqueue.events, npids, NULL);
		if (nevents == -1) {
			warn("kevent");
			error = 1;
			goto out;
		}
		error = kqueue_handle_events(&ctx, nevents);
		if (error)
			goto out;
	}

	while ((pid = MAP_ITERATE(ctx.pids, &it)) != NULL)
		printf("%d\n", *pid);

out:
	if (kq != -1)
		close(kq);
	context_free(&ctx);
	return error;
}

static void
usage(void)
{
	fprintf(stderr, "usage: robsd-wait [-a] pid ...\n");
	exit(1);
}

static void
context_free(struct context *ctx)
{
	VECTOR_FREE(ctx->kqueue.changes);
	VECTOR_FREE(ctx->kqueue.events);
	MAP_FREE(ctx->pids);
}

static void
kqueue_setup(struct context *ctx)
{
	struct map_iterator it = {0};
	int *pid;
	int i = 0;
	int npids;

	npids = pid_count(ctx);
	if (VECTOR_INIT(ctx->kqueue.changes) ||
	    VECTOR_RESERVE(ctx->kqueue.changes, (size_t)npids))
		err(1, NULL);
	if (VECTOR_INIT(ctx->kqueue.events) ||
	    VECTOR_RESERVE(ctx->kqueue.events, (size_t)npids))
		err(1, NULL);

	while ((pid = MAP_ITERATE(ctx->pids, &it)) != NULL) {
		EV_SET(&ctx->kqueue.changes[i++], *pid, EVFILT_PROC, EV_ADD,
		    NOTE_EXIT, 0, NULL);
	}
}

static int
kqueue_handle_events(struct context *ctx, int nevents)
{
	int error = 0;
	int i;

	for (i = 0; i < nevents; i++) {
		const struct kevent *kev = &ctx->kqueue.events[i];
		int pid;

		pid = kev->ident;
		if (kev->flags & EV_ERROR) {
			if (kev->data == ESRCH) { /* process already gone */
				MAP_REMOVE(ctx->pids, MAP_FIND(ctx->pids, pid));
			} else {
				warnc(kev->data, "kevent");
				error = 1;
			}
		} else if (kev->fflags & NOTE_EXIT) {
			MAP_REMOVE(ctx->pids, MAP_FIND(ctx->pids, pid));
		} else {
			warnx("unknown kevent: ident %lu, filter %x, "
			    "flags %x, fflags %x, data %lld",
			    kev->ident, kev->filter, kev->flags, kev->fflags,
			    kev->data);
			error = 1;
		}
	}

	return error;
}

static int
parse_pids(struct context *ctx, int argc, char **argv)
{
	int error = 0;
	int i;

	if (MAP_INIT(ctx->pids))
		err(1, NULL);
	for (i = 0; i < argc; i++) {
		const char *errstr;
		long long pid;

		pid = strtonum(argv[i], 1, INT_MAX, &errstr);
		if (pid > 0) {
			if (MAP_INSERT_VALUE(ctx->pids, pid, pid) == NULL)
				err(1, NULL);
		} else {
			warnx("%s %s", argv[i], errstr);
			error = 1;
		}
	}
	return error;
}

static int
pid_count(struct context *ctx)
{
	struct map_iterator it = {0};
	int npids = 0;

	while (MAP_ITERATE(ctx->pids, &it) != NULL)
		npids++;
	return npids;
}

#else

int
main(void)
{
	return 0;
}

#endif
