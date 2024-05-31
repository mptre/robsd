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

struct wait_context {
	MAP(int,, int)	pids;

	struct {
		VECTOR(struct kevent)	changes;
		VECTOR(struct kevent)	events;
	} kqueue;
};

static void	usage(void) __attribute__((__noreturn__));

static void	context_free(struct wait_context *);
static void	kqueue_setup(struct wait_context *);
static int	kqueue_handle_events(struct wait_context *, int);
static int	parse_pids(struct wait_context *, int, char **);
static int	pid_count(struct wait_context *);

int
main(int argc, char *argv[])
{
	struct wait_context c = {0};
	MAP_ITERATOR(c.pids) it = {0};
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

	if (parse_pids(&c, argc, argv)) {
		error = 1;
		goto out;
	}

	kq = kqueue();
	if (kq == -1) {
		warn("kqueue");
		error = 1;
		goto out;
	}
	kqueue_setup(&c);

	npids = pid_count(&c);
	nevents = kevent(kq, c.kqueue.changes, npids,
	    c.kqueue.events, npids, NULL);
	if (nevents == -1) {
		warn("kevent");
		error = 1;
		goto out;
	}
	error = kqueue_handle_events(&c, nevents);
	if (error)
		goto out;

	while (waitall && pid_count(&c) > 0) {
		nevents = kevent(kq, NULL, 0, c.kqueue.events, npids, NULL);
		if (nevents == -1) {
			warn("kevent");
			error = 1;
			goto out;
		}
		error = kqueue_handle_events(&c, nevents);
		if (error)
			goto out;
	}

	while (MAP_ITERATE(c.pids, &it))
		printf("%d\n", *it.val);

out:
	if (kq != -1)
		close(kq);
	context_free(&c);
	return error;
}

static void
usage(void)
{
	fprintf(stderr, "usage: robsd-wait [-a] pid ...\n");
	exit(1);
}

static void
context_free(struct wait_context *c)
{
	VECTOR_FREE(c->kqueue.changes);
	VECTOR_FREE(c->kqueue.events);
	MAP_FREE(c->pids);
}

static void
kqueue_setup(struct wait_context *c)
{
	MAP_ITERATOR(c->pids) it = {0};
	int i = 0;
	size_t npids;

	npids = (size_t)pid_count(c);
	if (VECTOR_INIT(c->kqueue.changes) ||
	    VECTOR_RESERVE(c->kqueue.changes, npids))
		err(1, NULL);
	if (VECTOR_INIT(c->kqueue.events) ||
	    VECTOR_RESERVE(c->kqueue.events, npids))
		err(1, NULL);

	while (MAP_ITERATE(c->pids, &it)) {
		EV_SET(&c->kqueue.changes[i++], *it.val, EVFILT_PROC, EV_ADD,
		    NOTE_EXIT, 0, NULL);
	}
}

static int
kqueue_handle_events(struct wait_context *c, int nevents)
{
	int error = 0;
	int i;

	for (i = 0; i < nevents; i++) {
		const struct kevent *kev = &c->kqueue.events[i];
		int pid;

		pid = (int)kev->ident;
		if (kev->flags & EV_ERROR) {
			if (kev->data == ESRCH) { /* process already gone */
				MAP_REMOVE(c->pids, pid);
			} else {
				warnc(kev->data, "kevent");
				error = 1;
			}
		} else if (kev->fflags & NOTE_EXIT) {
			MAP_REMOVE(c->pids, pid);
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
parse_pids(struct wait_context *c, int argc, char **argv)
{
	int error = 0;
	int i;

	if (MAP_INIT(c->pids))
		err(1, NULL);
	for (i = 0; i < argc; i++) {
		const char *errstr;
		long long pid;

		pid = strtonum(argv[i], 1, INT_MAX, &errstr);
		if (pid > 0) {
			if (MAP_INSERT_VALUE(c->pids, pid, pid) == NULL)
				err(1, NULL);
		} else {
			warnx("%s %s", argv[i], errstr);
			error = 1;
		}
	}
	return error;
}

static int
pid_count(struct wait_context *c)
{
	MAP_ITERATOR(c->pids) it = {0};
	int npids = 0;

	while (MAP_ITERATE(c->pids, &it))
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
