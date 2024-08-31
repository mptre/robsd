#include "invocation.h"

#include "config.h"

#include <dirent.h>
#include <err.h>
#include <errno.h>
#include <fnmatch.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>

#include "libks/arena-buffer.h"
#include "libks/arena.h"
#include "libks/buffer.h"
#include "libks/vector.h"

struct invocation_state {
	const char			*robsdir;
	const char			*keepdir;
	VECTOR(struct invocation_entry)	 directories;
};

static int	directory_asc_cmp(const struct invocation_entry *,
    const struct invocation_entry *);
static int	directory_desc_cmp(const struct invocation_entry *,
    const struct invocation_entry *);

static int
invocation_read(struct invocation_state *is, const char *directory,
    int (*match)(const struct dirent *, void *), void *arg)
{
	char path[PATH_MAX];
	DIR *dir;
	int error = 0;

	dir = opendir(directory);
	if (dir == NULL) {
		warn("opendir: %s", directory);
		return 1;
	}

	for (;;) {
		const struct dirent *de;
		struct invocation_entry *entry;

		errno = 0;
		de = readdir(dir);
		if (de == NULL) {
			if (errno != 0) {
				warn("readdir: %s", directory);
				error = 1;
			}
			break;
		}
		if (de->d_name[0] == '.')
			continue;
		if (!match(de, arg))
			continue;

		entry = VECTOR_ALLOC(is->directories);
		if (entry == NULL)
			err(1, NULL);
		(void)snprintf(path, sizeof(path), "%s/%s",
		    directory, de->d_name);
		(void)snprintf(entry->path, sizeof(entry->path), "%s", path);
		(void)snprintf(entry->basename, sizeof(entry->basename), "%s",
		    de->d_name);
	}

	closedir(dir);
	return error;
}

static int
match_directory(const struct dirent *de, void *arg)
{
	char path[PATH_MAX];
	const struct invocation_state *is = arg;

	if (de->d_type != DT_DIR)
		return 0;

	(void)snprintf(path, sizeof(path), "%s/%s",
	    is->robsdir, de->d_name);
	if (strcmp(path, is->keepdir) == 0)
		return 0;

	return 1;
}

struct invocation_state *
invocation_alloc(const char *robsddir, const char *keepdir,
    struct arena_scope *s, unsigned int flags)
{
	struct invocation_state *is = NULL;
	int error = 0;

	is = arena_calloc(s, 1, sizeof(*is));
	is->robsdir = robsddir;
	is->keepdir = keepdir;
	if (VECTOR_INIT(is->directories))
		err(1, NULL);

	if (invocation_read(is, robsddir, match_directory, is)) {
		error = 1;
		goto out;
	}
	if (flags & INVOCATION_SORT_ASC)
		VECTOR_SORT(is->directories, directory_asc_cmp);
	else if (flags & INVOCATION_SORT_DESC)
		VECTOR_SORT(is->directories, directory_desc_cmp);

out:
	if (error) {
		invocation_free(is);
		return NULL;
	}
	return is;
}

void
invocation_free(struct invocation_state *is)
{
	if (is == NULL)
		return;
	VECTOR_FREE(is->directories);
}

const struct invocation_entry *
invocation_walk(struct invocation_state *is)
{
	return VECTOR_POP(is->directories);
}

static int
match_glob(const struct dirent *de, void *arg)
{
	const char *pattern = arg;

	return fnmatch(pattern, de->d_name, 0) != FNM_NOMATCH;
}

struct invocation_state *
invocation_find(const char *directory, const char *pattern,
    struct arena_scope *s)
{
	struct invocation_state *is = NULL;
	int error = 0;

	is = arena_calloc(s, 1, sizeof(*is));
	if (VECTOR_INIT(is->directories))
		err(1, NULL);
	if (invocation_read(is, directory, match_glob, (void *)pattern))
		error = 1;
	if (error) {
		invocation_free(is);
		return NULL;
	}
	return is;
}

int
invocation_has_tag(const char *directory, const char *tag,
    struct arena *scratch)
{
	struct buffer *bf;
	const char *buf, *path, *str;
	int found = 0;

	arena_scope(scratch, s);

	path = arena_sprintf(&s, "%s/tags", directory);
	bf = arena_buffer_read(&s, path);
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
	return found;
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
