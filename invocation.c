#include "invocation.h"

#include <sys/types.h>

#include <dirent.h>
#include <err.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "extern.h"
#include "vector.h"

struct directory {
	char	path[PATH_MAX];
};

struct invocation {
	const char		*iv_robsddir;
	const char		*iv_keepdir;
	VECTOR(struct directory) iv_directories;
};

static int	invocation_read(struct invocation *, DIR *);

static int	directory_cmp(const void *, const void *);

struct invocation *
invocation_alloc(const struct config *cf)
{
	DIR *dir = NULL;
	struct invocation *iv;
	struct variable *va;
	const char *keepdir = NULL;
	const char *robsddir;
	int error = 0;

	va = config_find(cf, "robsddir");
	if (va == NULL) {
		error = 1;
		goto out;
	}
	robsddir = variable_get_value(va)->str;
	dir = opendir(robsddir);
	if (dir == NULL) {
		warn("opendir: %s", robsddir);
		error = 1;
		goto out;
	}

	va = config_find(cf, "keep-dir");
	if (va != NULL)
		keepdir = variable_get_value(va)->str;

	iv = calloc(1, sizeof(*iv));
	if (iv == NULL)
		err(1, NULL);
	iv->iv_robsddir = robsddir;
	iv->iv_keepdir = keepdir;
	if (VECTOR_INIT(iv->iv_directories) == NULL)
		err(1, NULL);

	if (invocation_read(iv, dir)) {
		error = 1;
		goto out;
	}
	if (!VECTOR_EMPTY(iv->iv_directories)) {
		qsort(iv->iv_directories, VECTOR_LENGTH(iv->iv_directories),
		    sizeof(*iv->iv_directories), directory_cmp);
	}

out:
	if (dir != NULL)
		closedir(dir);
	if (error) {
		invocation_free(iv);
		return NULL;
	}
	return iv;
}

void
invocation_free(struct invocation *iv)
{
	if (iv == NULL)
		return;
	VECTOR_FREE(iv->iv_directories);
	free(iv);
}

const char *
invocation_walk(struct invocation *iv)
{
	if (VECTOR_EMPTY(iv->iv_directories))
		return NULL;
	return VECTOR_POP(iv->iv_directories)->path;
}

static int
invocation_read(struct invocation *iv, DIR *dir)
{
	char path[PATH_MAX];
	struct dirent *ent;

	for (;;) {
		struct directory *d;

		errno = 0;
		ent = readdir(dir);
		if (ent == NULL) {
			if (errno != 0) {
				warn("readdir: %s", iv->iv_robsddir);
				return 1;
			}
			break;
		}
		if (ent->d_type != DT_DIR || ent->d_name[0] == '.')
			continue;

		(void)snprintf(path, sizeof(path), "%s/%s",
		    iv->iv_robsddir, ent->d_name);
		if (strcmp(path, iv->iv_keepdir) == 0)
			continue;

		d = VECTOR_ALLOC(iv->iv_directories);
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
