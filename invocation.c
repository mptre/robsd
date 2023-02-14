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

#include "alloc.h"
#include "buffer.h"
#include "vector.h"

struct invocation_state {
	const char			*robsdir;
	const char			*keepdir;
	VECTOR(struct invocation_entry)	 directories;
};

static int	invocation_read(struct invocation_state *, DIR *);

static int	directory_cmp(const struct invocation_entry *,
    const struct invocation_entry *);

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
	VECTOR_SORT(s->directories, directory_cmp);

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

struct invocation_entry *
invocation_find(const char *directory, const char *pattern)
{
	VECTOR(struct invocation_entry) entries;
	DIR *dir;
	int error = 0;

	dir = opendir(directory);
	if (dir == NULL)
		return NULL;
	if (VECTOR_INIT(entries) == NULL)
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

		entry = VECTOR_ALLOC(entries);
		if (entry == NULL)
			err(1, NULL);
		(void)snprintf(entry->path, sizeof(entry->path), "%s/%s",
		    directory, de->d_name);
		(void)snprintf(entry->basename, sizeof(entry->basename), "%s",
		    de->d_name);
	}

out:
	if (error) {
		VECTOR_FREE(entries);
		entries = NULL;
	}
	closedir(dir);
	return entries;
}

void
invocation_find_free(struct invocation_entry *entries)
{
	if (entries == NULL)
		return;
	VECTOR_FREE(entries);
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
		memcpy(entry->path, path, sizeof(path));
	}
	return 0;
}

static int
directory_cmp(const struct invocation_entry *a,
    const struct invocation_entry *b)
{
	return strcmp(a->path, b->path);
}
