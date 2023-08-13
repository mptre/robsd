#include "invocation.h"

#include "config.h"

#include <sys/types.h>

#include <dirent.h>
#include <err.h>
#include <errno.h>
#include <fnmatch.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "libks/buffer.h"
#include "libks/vector.h"

#include "alloc.h"

struct invocation_state {
	const char			*robsdir;
	const char			*keepdir;
	VECTOR(struct invocation_entry)	 directories;
};

static int	invocation_read(struct invocation_state *, DIR *);

static int	directory_asc_cmp(const struct invocation_entry *,
    const struct invocation_entry *);
static int	directory_desc_cmp(const struct invocation_entry *,
    const struct invocation_entry *);

struct invocation_state *
invocation_alloc(const char *robsddir, const char *keepdir, unsigned int flags)
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
	if (VECTOR_INIT(s->directories))
		err(1, NULL);

	if (invocation_read(s, dir)) {
		error = 1;
		goto out;
	}
	if (flags & INVOCATION_SORT_ASC)
		VECTOR_SORT(s->directories, directory_asc_cmp);
	else if (flags & INVOCATION_SORT_DESC)
		VECTOR_SORT(s->directories, directory_desc_cmp);

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

const struct invocation_entry *
invocation_walk(struct invocation_state *s)
{
	return VECTOR_POP(s->directories);
}

struct invocation_state *
invocation_find(const char *directory, const char *pattern)
{
	DIR *dir = NULL;
	struct invocation_state *s = NULL;
	int error = 0;

	dir = opendir(directory);
	if (dir == NULL) {
		warn("opendir: %s", directory);
		error = 1;
		goto out;
	}
	s = ecalloc(1, sizeof(*s));
	if (VECTOR_INIT(s->directories))
		err(1, NULL);

	for (;;) {
		struct dirent *de;
		struct invocation_entry *entry;

		errno = 0;
		de = readdir(dir);
		if (de == NULL) {
			if (errno != 0) {
				warn("readdir: %s", directory);
				error = 1;
				goto out;
			}
			break;
		}
		if (fnmatch(pattern, de->d_name, 0) == FNM_NOMATCH)
			continue;

		entry = VECTOR_ALLOC(s->directories);
		if (entry == NULL)
			err(1, NULL);
		(void)snprintf(entry->path, sizeof(entry->path), "%s/%s",
		    directory, de->d_name);
		(void)snprintf(entry->basename, sizeof(entry->basename), "%s",
		    de->d_name);
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

int
invocation_has_tag(const char *directory, const char *tag)
{
	char path[PATH_MAX];
	struct buffer *bf;
	const char *buf, *str;
	size_t pathsiz = sizeof(path);
	int found = 0;
	int n;

	n = snprintf(path, pathsiz, "%s/tags", directory);
	if (n < 0 || (size_t)n >= pathsiz) {
		warnc(ENAMETOOLONG, "%s", __func__);
		return 0;
	}

	bf = buffer_read(path);
	if (bf == NULL)
		return 0;
	buffer_putc(bf, '\0');
	buf = buffer_get_ptr(bf);
	str = strstr(buf, tag);
	if (str != NULL) {
		size_t taglen;

		taglen = strlen(tag);
		if ((str == buf || str[-1] == ' ') &&
		    (str[taglen] == '\0' || str[taglen] == ' ' ||
		     str[taglen] == '\n'))
			found = 1;
	}
	buffer_free(bf);
	return found;
}

static int
invocation_read(struct invocation_state *s, DIR *dir)
{
	char path[PATH_MAX];

	for (;;) {
		struct dirent *de;
		struct invocation_entry *entry;

		errno = 0;
		de = readdir(dir);
		if (de == NULL) {
			if (errno != 0) {
				warn("readdir: %s", s->robsdir);
				return 1;
			}
			break;
		}
		if (de->d_type != DT_DIR || de->d_name[0] == '.')
			continue;

		(void)snprintf(path, sizeof(path), "%s/%s",
		    s->robsdir, de->d_name);
		if (strcmp(path, s->keepdir) == 0)
			continue;

		entry = VECTOR_ALLOC(s->directories);
		if (entry == NULL)
			err(1, NULL);
		(void)snprintf(entry->path, sizeof(entry->path), "%s", path);
		(void)snprintf(entry->basename, sizeof(entry->basename), "%s",
		    de->d_name);
	}
	return 0;
}

static int
directory_asc_cmp(const struct invocation_entry *a,
    const struct invocation_entry *b)
{
	return -strcmp(a->path, b->path);
}

static int
directory_desc_cmp(const struct invocation_entry *a,
    const struct invocation_entry *b)
{
	return strcmp(a->path, b->path);
}
