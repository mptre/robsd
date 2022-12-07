#include "invocation.h"

#include <sys/types.h>

#include <dirent.h>
#include <err.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "alloc.h"
#include "vector.h"

struct directory {
	char	path[PATH_MAX];
};

struct invocation_state {
	const char		*robsdir;
	const char		*keepdir;
	VECTOR(struct directory) directories;
};

static int	invocation_read(struct invocation_state *, DIR *);

static int	directory_cmp(const void *, const void *);

struct invocation_state *
invocation_alloc(const char *robsddir, const char *keepdir)
{
	DIR *dir = NULL;
	struct invocation_state *s = NULL;
	int error = 0;

	dir = opendir(robsddir);
	if (dir == NULL) {
		warn("opendir: %s", robsddir);
		error = 1;
		goto out;
	}

	s = ecalloc(1, sizeof(*s));
	s->robsdir = robsddir;
	s->keepdir = keepdir;
	if (VECTOR_INIT(s->directories) == NULL)
		err(1, NULL);

	if (invocation_read(s, dir)) {
		error = 1;
		goto out;
	}
	if (!VECTOR_EMPTY(s->directories)) {
		qsort(s->directories, VECTOR_LENGTH(s->directories),
		    sizeof(*s->directories), directory_cmp);
	}

out:
	if (dir != NULL)
		closedir(dir);
	if (error) {
		invocation_free(s);
		return NULL;
	}
	return s;
}

void
invocation_free(struct invocation_state *s)
{
	if (s == NULL)
		return;

	VECTOR_FREE(s->directories);
	free(s);
}

const char *
invocation_walk(struct invocation_state *s)
{
	if (VECTOR_EMPTY(s->directories))
		return NULL;
	return VECTOR_POP(s->directories)->path;
}

static int
invocation_read(struct invocation_state *s, DIR *dir)
{
	char path[PATH_MAX];

	for (;;) {
		struct directory *d;
		struct dirent *ent;

		errno = 0;
		ent = readdir(dir);
		if (ent == NULL) {
			if (errno != 0) {
				warn("readdir: %s", s->robsdir);
				return 1;
			}
			break;
		}
		if (ent->d_type != DT_DIR || ent->d_name[0] == '.')
			continue;

		(void)snprintf(path, sizeof(path), "%s/%s",
		    s->robsdir, ent->d_name);
		if (strcmp(path, s->keepdir) == 0)
			continue;

		d = VECTOR_ALLOC(s->directories);
		if (d == NULL)
			err(1, NULL);
		memcpy(d->path, path, sizeof(path));
	}
	return 0;
}

static int
directory_cmp(const void *p1, const void *p2)
{
	const struct directory *d1 = p1;
	const struct directory *d2 = p2;

	return strcmp(d1->path, d2->path);
}
