#include "regress-html.h"

#include "config.h"

#include <sys/types.h>
#include <sys/stat.h>

#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "libks/arena.h"
#include "libks/buffer.h"
#include "libks/map.h"
#include "libks/vector.h"

#include "html.h"
#include "invocation.h"
#include "regress-log.h"
#include "step.h"

#define FOR_RUN_STATUSES(OP)					\
	/* status  failure */					\
	OP(PASS,   0)						\
	OP(FAIL,   1)						\
	OP(XFAIL,  0)						\
	OP(XPASS,  1)						\
	OP(SKIP,   0)

struct regress_html {
	VECTOR(struct regress_invocation)	 invocations;
	MAP(const char, *, struct suite)	 suites;
	const char				*output;
	struct arena_scope			*arena;
	struct html				*html;
	struct buffer				*scratch;
};

struct regress_invocation {
	char		*arch;
	char		*date;
	char		*dmesg;
	char		*comment;
	int64_t		 time;
	struct {
		char	*path;
		int	 count;
	} patches;
	struct {
		int64_t	seconds;
		enum duration_delta {
			NONE,
			FASTER,
			SLOWER,
		} delta;
	} duration;
	int		 total;
	int		 fail;
	unsigned int	 flags;
#define REGRESS_INVOCATION_CVS		0x00000001u
};

#define OP(s, ...) s,
enum run_status {
	FOR_RUN_STATUSES(OP)
};
#undef OP

struct run {
	char		*log;
	int64_t		 time;
	int64_t		 exit;
	enum run_status	 status;
};

struct suite {
	const char		*name;
	int			 fail;
	VECTOR(struct run)	 runs;
};

static int				  parse_invocation(
    struct regress_html *, const char *, const char *, const char *,
    struct arena_scope *);
static int				  parse_run_log(struct regress_html *,
    const struct run *, const char *, const char *, enum run_status *,
    struct arena_scope *);
static struct regress_invocation	 *create_regress_invocation(
    struct regress_html *, const char *, const char *, int64_t, int64_t,
    struct arena_scope *);
static int				  copy_files(struct regress_html *,
    const struct regress_invocation *, const char *, struct arena_scope *);
static int				  copy_patches(struct regress_html *,
    struct regress_invocation *, const char *, struct arena_scope *);
static struct suite			 *find_suite(struct regress_html *,
    const char *);
static struct suite			**sort_suites(struct regress_html *);
static const char			 *render_duration(
    const struct regress_invocation *, struct arena_scope *);
static const char			 *render_rate(
    const struct regress_invocation *, struct arena_scope *);

static int	regress_invocation_cmp(const struct regress_invocation *,
    const struct regress_invocation *);
static int	run_cmp(const struct run *, const struct run *);
static int	suite_cmp(struct suite *const *, struct suite *const *);

static int	copy_log(struct regress_html *, const char *,
    const struct buffer *, struct arena_scope *);
static int	write_log(const char *, const struct buffer *);

static void	render_pass_rates(struct regress_html *, struct arena_scope *);
static void	render_dates(struct regress_html *);
static void	render_durations(struct regress_html *, struct arena_scope *);
static void	render_changelog(struct regress_html *);
static void	render_patches(struct regress_html *, struct arena_scope *);
static void	render_arches(struct regress_html *);
static void	render_suite(struct regress_html *,
    struct suite *, struct arena_scope *);
static void	render_run(struct regress_html *,
    const struct run *);

static const char		*cvsweb_url(const char *, struct arena_scope *);
static enum duration_delta	 duration_delta(int64_t, int64_t);
static int			 is_run_status_failure(enum run_status);
static const char		*run_status_str(enum run_status);

struct regress_html *
regress_html_alloc(const char *directory, struct arena_scope *s)
{
	struct regress_html *r;

	r = arena_calloc(s, 1, sizeof(*r));
	if (VECTOR_INIT(r->invocations))
		err(1, NULL);
	if (MAP_INIT(r->suites))
		err(1, NULL);
	r->output = directory;
	r->arena = s;
	r->html = html_alloc();
	r->scratch = buffer_alloc(1 << 10);
	if (r->scratch == NULL)
		err(1, NULL);
	return r;
}

void
regress_html_free(struct regress_html *r)
{
	struct map_iterator it = {0};
	struct suite *suite;

	if (r == NULL)
		return;

	VECTOR_FREE(r->invocations);
	while ((suite = MAP_ITERATE(r->suites, &it)) != NULL) {
		VECTOR_FREE(suite->runs);
		MAP_REMOVE(r->suites, suite);
	}
	MAP_FREE(r->suites);
	html_free(r->html);
	buffer_free(r->scratch);
}

int
regress_html_parse(struct regress_html *r, const char *arch,
    const char *robsddir)
{
	ARENA arena[256 * 1024];
	const char *keepdir;
	struct invocation_state *is;
	const struct invocation_entry *entry;
	int error = 0;
	int ninvocations = 0;

	if (arena_init(arena, ARENA_FATAL))
		err(1, "arena_init");

	keepdir = arena_printf(r->arena, "%s/attic", robsddir);
	is = invocation_alloc(robsddir, keepdir, INVOCATION_SORT_ASC);
	if (is == NULL) {
		error = 1;
		goto out;
	}
	while ((entry = invocation_walk(is)) != NULL) {
		ARENA_SCOPE s = arena_scope(arena);

		if (parse_invocation(r, arch,
		    entry->path, entry->basename, &s)) {
			error = 1;
			goto out;
		}

		if (++ninvocations >= 2) {
			size_t n;

			n = VECTOR_LENGTH(r->invocations);
			r->invocations[n - 1].duration.delta = duration_delta(
			    r->invocations[n - 1].duration.seconds,
			    r->invocations[n - 2].duration.seconds);
		}
	}

out:
	invocation_free(is);
	arena_free(arena);
	return error;
}

int
regress_html_render(struct regress_html *r)
{
	ARENA arena[256 * 1024];
	struct suite **suites;
	struct html *html = r->html;
	const char *path;
	int error;

	if (arena_init(arena, ARENA_FATAL))
		err(1, "arena_init");

	VECTOR_SORT(r->invocations, regress_invocation_cmp);

	HTML_HEAD(html) {
		HTML_NODE(html, "title")
			HTML_TEXT(html, "OpenBSD regress");
	}

	HTML_NODE(html, "h1")
		HTML_TEXT(html, "OpenBSD regress latest test results");

	suites = sort_suites(r);
	HTML_NODE(html, "table") {
		ARENA_SCOPE s = arena_scope(arena);
		size_t i;

		HTML_NODE(html, "thead") {
			render_pass_rates(r, &s);
			render_dates(r);
			render_durations(r, &s);
			render_changelog(r);
			render_patches(r, &s);
			render_arches(r);
		}

		HTML_NODE(html, "tbody") {
			for (i = 0; i < VECTOR_LENGTH(suites); i++)
				render_suite(r, suites[i], &s);
		}
	}
	VECTOR_FREE(suites);

	ARENA_SCOPE s = arena_scope(arena);
	path = arena_printf(&s, "%s/index.html", r->output);
	/* coverity[leaked_storage: FALSE] */
	error = html_write(r->html, path);

	arena_free(arena);
	return error;
}

/*
 * Returns non-zero if the given step name represents a regress suite. The
 * regress configuration cannot be used here as we might render runs referring
 * to suites deleted from the configuration by now.
 */
static int
is_regress_step(const char *name)
{
	return strchr(name, '/') != NULL;
}

static int
parse_invocation(struct regress_html *r, const char *arch,
    const char *directory, const char *date, struct arena_scope *s)
{
	struct buffer *dmesg = NULL;
	struct step *end, *steps;
	struct regress_invocation *ri;
	const char *step_path;
	int64_t duration, time;
	size_t i;
	int error = 0;
	int rv;

	step_path = arena_printf(s, "%s/step.csv", directory);
	steps = steps_parse(step_path);
	if (steps == NULL)
		return 1;
	if (VECTOR_EMPTY(steps)) {
		warnx("%s: no steps found", step_path);
		error = 1;
		goto out;
	}

	end = steps_find_by_name(steps, "end");
	if (end == NULL) {
		warnx("%s: end step not found", step_path);
		error = 1;
		goto out;
	}
	duration = step_get_field(end, "duration")->integer;
	time = step_get_field(&steps[0], "time")->integer;
	ri = create_regress_invocation(r, arch, date, time, duration, s);
	if (ri == NULL) {
		error = 1;
		goto out;
	}
	if (copy_files(r, ri, directory, s)) {
		error = 1;
		goto out;
	}
	if (invocation_has_tag(directory, "cvs"))
		ri->flags |= REGRESS_INVOCATION_CVS;
	rv = copy_patches(r, ri, directory, s);
	if (rv == -1) {
		error = 1;
		goto out;
	}
	ri->patches.count = rv;

	for (i = 0; i < VECTOR_LENGTH(steps); i++) {
		struct suite *suite;
		struct run *run;
		const char *log_path, *name;
		enum run_status status;

		name = step_get_field(&steps[i], "name")->str;
		if (!is_regress_step(name))
			continue;

		ri->total++;

		suite = find_suite(r, name);
		run = VECTOR_CALLOC(suite->runs);
		if (run == NULL)
			err(1, NULL);
		run->log = arena_printf(r->arena, "%s/%s/%s",
		    arch, ri->date, step_get_field(&steps[i], "log")->str);
		run->time = time;
		run->exit = step_get_field(&steps[i], "exit")->integer;

		log_path = arena_printf(s, "%s/%s",
		    directory, step_get_field(&steps[i], "log")->str);
		if (parse_run_log(r, run, log_path, run->log, &status, s)) {
			error = 1;
			goto out;
		}
		run->status = status;
		if (is_run_status_failure(run->status)) {
			ri->fail++;
			suite->fail++;
		}
	}

out:
	buffer_free(dmesg);
	steps_free(steps);
	return error;
}

static int
parse_run_log(struct regress_html *r, const struct run *run,
    const char *src_path, const char *dst_path, enum run_status *status,
    struct arena_scope *s)
{
	struct buffer *bf = r->scratch;
	int error;

	if (run->exit != 0) {
		/*
		 * Give higher precedence to XPASS than FAIL, matches what
		 * bluhm@ does.
		 */
		*status = regress_log_peek(src_path, REGRESS_LOG_XPASSED) > 0 ?
		    XPASS : FAIL;
	} else if (regress_log_peek(src_path, REGRESS_LOG_XFAILED) > 0) {
		*status = XFAIL;
	} else if (regress_log_peek(src_path, REGRESS_LOG_SKIPPED) > 0) {
		*status = SKIP;
	} else {
		*status = PASS;
	}

	buffer_reset(bf);
	if (regress_log_parse(src_path, bf,
	    REGRESS_LOG_FAILED | REGRESS_LOG_SKIPPED | REGRESS_LOG_XFAILED |
	    REGRESS_LOG_XPASSED) > 0) {
		error = copy_log(r, dst_path, bf, s);
	} else if (regress_log_parse(src_path, bf, REGRESS_LOG_ERROR) > 0) {
		error = copy_log(r, dst_path, bf, s);
	} else if (regress_log_trim(src_path, bf) > 0) {
		error = copy_log(r, dst_path, bf, s);
	} else {
		warnx("%s: failed to parse log", src_path);
		error = 1;
	}

	return error;
}

static struct regress_invocation *
create_regress_invocation(struct regress_html *r, const char *arch,
    const char *date, int64_t time, int64_t duration, struct arena_scope *s)
{
	struct regress_invocation *ri = NULL;
	const char *path;

	/*
	 * Create architecture output directory, could already have been created
	 * while handling a previous invocation.
	 */
	path = arena_printf(s, "%s/%s", r->output, arch);
	if (mkdir(path, 0755) == -1 && errno != EEXIST) {
		warn("mkdir: %s", path);
		return NULL;
	}
	/* Create invocation output directory. */
	path = arena_printf(s, "%s/%s/%s", r->output, arch, date);
	if (mkdir(path, 0755) == -1) {
		warn("mkdir: %s", path);
		return NULL;
	}

	ri = VECTOR_CALLOC(r->invocations);
	if (ri == NULL)
		err(1, NULL);
	ri->arch = arena_strdup(r->arena, arch);
	ri->date = arena_strdup(r->arena, date);
	ri->time = time;
	ri->duration.seconds = duration;

	ri->dmesg = arena_printf(r->arena, "%s/%s/dmesg", arch, date);
	ri->comment = arena_printf(r->arena, "%s/%s/comment", arch, date);
	ri->patches.path = arena_printf(r->arena, "%s/%s/diff", arch, date);

	return ri;
}

static int
copy_files(struct regress_html *r, const struct regress_invocation *ri,
    const char *directory, struct arena_scope *s)
{
	struct buffer *bf = NULL;
	const char *path;
	int error = 0;

	path = arena_printf(s, "%s/dmesg", directory);
	bf = buffer_read(path);
	if (bf == NULL) {
		warn("%s", path);
	} else {
		if (copy_log(r, ri->dmesg, bf, s)) {
			error = 1;
			goto out;
		}
	}
	buffer_free(bf);

	path = arena_printf(s, "%s/comment", directory);
	bf = buffer_read(path);
	if (bf == NULL) {
		warn("%s", path);
	} else {
		if (copy_log(r, ri->comment, bf, s)) {
			error = 1;
			goto out;
		}
	}

out:
	buffer_free(bf);
	return error;
}

static int
copy_patches(struct regress_html *r, struct regress_invocation *ri,
    const char *directory, struct arena_scope *s)
{
	struct invocation_state *is;
	const struct invocation_entry *entry;
	const char *path;
	int error = 0;
	int npatches = 0;

	is = invocation_find(directory, "src.diff.*");
	if (is == NULL)
		return 0;

	path = arena_printf(s, "%s/%s", r->output, ri->patches.path);
	if (mkdir(path, 0755) == -1) {
		warn("mkdir: %s", path);
		error = 1;
		goto out;
	}
	while ((entry = invocation_walk(is)) != NULL) {
		struct buffer *bf;

		bf = buffer_read(entry->path);
		if (bf == NULL) {
			warn("%s", entry->path);
			error = 1;
			goto out;
		}
		path = arena_printf(s, "%s/%s/%s",
		    r->output, ri->patches.path, entry->basename);
		error = write_log(path, bf);
		buffer_free(bf);
		if (error) {
			error = 1;
			goto out;
		}
		npatches++;
	}

	error = 0;

out:
	invocation_free(is);
	/* coverity[leaked_storage: FALSE] */
	return error ? -1 : npatches;
}

static struct suite *
find_suite(struct regress_html *r, const char *name)
{
	struct suite *suite;

	suite = MAP_FIND(r->suites, name);
	if (suite == NULL) {
		suite = MAP_INSERT(r->suites, name);
		suite->name = MAP_KEY(r->suites, suite);
		if (VECTOR_INIT(suite->runs))
			err(1, NULL);
	}
	return suite;
}

static struct suite **
sort_suites(struct regress_html *r)
{
	VECTOR(struct suite *) all;
	VECTOR(struct suite *) pass;
	VECTOR(struct suite *) nonregress;
	struct map_iterator it = {0};
	struct suite **dst;
	struct suite *suite;
	size_t i;

	if (VECTOR_INIT(all))
		err(1, NULL);
	if (VECTOR_INIT(pass))
		err(1, NULL);
	if (VECTOR_INIT(nonregress))
		err(1, NULL);

	while ((suite = MAP_ITERATE(r->suites, &it)) != NULL) {
		if (suite->fail > 0) {
			dst = VECTOR_ALLOC(all);
		} else if (strncmp(suite->name, "../", 3) == 0) {
			/*
			 * Place step(s) outside of the regress directory last
			 * as they are often dependencies that are not that
			 * interesting.
			 */
			dst = VECTOR_ALLOC(nonregress);
		} else {
			dst = VECTOR_ALLOC(pass);
		}
		if (dst == NULL)
			err(1, NULL);
		*dst = suite;
	}
	VECTOR_SORT(all, suite_cmp);
	VECTOR_SORT(pass, suite_cmp);
	VECTOR_SORT(nonregress, suite_cmp);
	for (i = 0; i < VECTOR_LENGTH(pass); i++) {
		dst = VECTOR_ALLOC(all);
		if (dst == NULL)
			err(1, NULL);
		*dst = pass[i];
	}
	for (i = 0; i < VECTOR_LENGTH(nonregress); i++) {
		dst = VECTOR_ALLOC(all);
		if (dst == NULL)
			err(1, NULL);
		*dst = nonregress[i];
	}
	VECTOR_FREE(pass);
	VECTOR_FREE(nonregress);
	return all;
}

static const char *
render_duration(const struct regress_invocation *ri, struct arena_scope *s)
{
	const char *arrows[] = {
		[NONE]		= "",
		[FASTER]	= " &#8600;",
		[SLOWER]	= " &#8599;",
	};
	int64_t hours, minutes;

	hours = ri->duration.seconds / 3600;
	minutes = (ri->duration.seconds % 3600) / 60;
	return arena_printf(s, "%dh%dm<span>%s</span>",
	    (int)hours, (int)minutes, arrows[ri->duration.delta]);
}

static const char *
render_rate(const struct regress_invocation *ri, struct arena_scope *s)
{
	float rate = 0;

	if (ri->total > 0)
		rate = 1 - (ri->fail / (float)ri->total);
	return arena_printf(s, "%d%%", (int)(rate * 100));
}

static int
regress_invocation_cmp(const struct regress_invocation *a,
    const struct regress_invocation *b)
{
	/* Descending order. */
	if (a->time < b->time)
		return 1;
	if (a->time > b->time)
		return -1;
	return 0;
}

static int
run_cmp(const struct run *a, const struct run *b)
{
	/* Descending order. */
	if (a->time < b->time)
		return 1;
	if (a->time > b->time)
		return -1;
	return 0;
}

static int
suite_cmp(struct suite *const *a, struct suite *const *b)
{
	/* Descending order. */
	if ((*a)->fail < (*b)->fail)
		return 1;
	if ((*a)->fail > (*b)->fail)
		return -1;
	return strcmp((*a)->name, (*b)->name);
}

static int
copy_log(struct regress_html *r, const char *basename,
    const struct buffer *bf, struct arena_scope *s)
{
	const char *path;

	path = arena_printf(s, "%s/%s", r->output, basename);
	return write_log(path, bf);
}

static int
write_log(const char *path, const struct buffer *bf)
{
	FILE *fh;
	const char *buf;
	size_t buflen, n, nmemb;
	int error = 0;
	int fd;

	fd = open(path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0644);
	if (fd == -1) {
		if (errno == EEXIST)
			return 0;
		warn("open: %s", path);
		return 1;
	}
	fh = fdopen(fd, "we");
	if (fh == NULL) {
		warn("fdopen: %s", path);
		close(fd);
		return 1;
	}
	buf = buffer_get_ptr(bf);
	buflen = buffer_get_len(bf);
	nmemb = buflen > 0 ? 1 : 0;
	n = fwrite(buf, buflen, nmemb, fh);
	if (n < nmemb) {
		warn("fwrite: %s", path);
		error = 1;
	}
	fclose(fh);
	return error;
}

static void
render_pass_rates(struct regress_html *r, struct arena_scope *s)
{
	struct html *html = r->html;

	HTML_NODE(html, "tr") {
		size_t i;

		HTML_NODE(html, "th")
			HTML_TEXT(html, "pass rate");
		for (i = 0; i < VECTOR_LENGTH(r->invocations); i++) {
			const struct regress_invocation *ri = &r->invocations[i];

			HTML_NODE_ATTR(html, "th", HTML_ATTR("class", "pass"))
				HTML_TEXT(html, render_rate(ri, s));
		}
	}
}

static void
render_dates(struct regress_html *r)
{
	struct html *html = r->html;

	HTML_NODE(html, "tr") {
		size_t i;

		HTML_NODE(html, "th")
			HTML_TEXT(html, "date");
		for (i = 0; i < VECTOR_LENGTH(r->invocations); i++) {
			const struct regress_invocation *ri = &r->invocations[i];

			HTML_NODE_ATTR(html, "th", HTML_ATTR("class", "date"))
				HTML_TEXT(html, ri->date);
		}
	}
}

static void
render_durations(struct regress_html *r, struct arena_scope *s)
{
	struct html *html = r->html;

	HTML_NODE(html, "tr") {
		size_t i;

		HTML_NODE(html, "th")
			HTML_TEXT(html, "duration");
		for (i = 0; i < VECTOR_LENGTH(r->invocations); i++) {
			const struct regress_invocation *ri = &r->invocations[i];

			HTML_NODE_ATTR(html, "th",
			    HTML_ATTR("class", "duration"))
				HTML_TEXT(html, render_duration(ri, s));
		}
	}
}

static void
render_changelog(struct regress_html *r)
{
	struct html *html = r->html;

	HTML_NODE(html, "tr") {
		size_t i;

		HTML_NODE(html, "th")
			HTML_TEXT(html, "changelog");
		for (i = 0; i < VECTOR_LENGTH(r->invocations); i++) {
			const struct regress_invocation *ri = &r->invocations[i];

			HTML_NODE_ATTR(html, "th", HTML_ATTR("class", "cvs")) {
				if (ri->flags & REGRESS_INVOCATION_CVS) {
					HTML_NODE_ATTR(html, "a",
					    HTML_ATTR("href", ri->comment))
						HTML_TEXT(html, "cvs");
				} else {
					HTML_TEXT(html, "n/a");
				}
			}
		}
	}
}

static void
render_patches(struct regress_html *r, struct arena_scope *s)
{
	struct html *h = r->html;

	HTML_NODE(h, "tr") {
		size_t i;

		HTML_NODE(h, "th")
			HTML_TEXT(h, "patches");
		for (i = 0; i < VECTOR_LENGTH(r->invocations); i++) {
			const struct regress_invocation *ri = &r->invocations[i];

			HTML_NODE_ATTR(h, "th", HTML_ATTR("class", "patch")) {
				if (ri->patches.count > 0) {
					const char *text;

					text = arena_printf(s, "patches (%d)",
					    ri->patches.count);
					HTML_NODE_ATTR(h, "a",
					    HTML_ATTR("href", ri->patches.path))
						HTML_TEXT(h, text);
				} else {
					HTML_TEXT(h, "n/a");
				}
			}
		}
	}
}

static void
render_arches(struct regress_html *r)
{
	struct html *html = r->html;

	HTML_NODE(html, "tr") {
		size_t i;

		HTML_NODE(html, "th")
			HTML_TEXT(html, "architecture");
		for (i = 0; i < VECTOR_LENGTH(r->invocations); i++) {
			const struct regress_invocation *ri = &r->invocations[i];

			HTML_NODE_ATTR(html, "th", HTML_ATTR("class", "arch")) {
				HTML_NODE_ATTR(html, "a",
				    HTML_ATTR("href", ri->dmesg))
					HTML_TEXT(html, ri->arch);
			}
		}
	}
}

static void
render_suite(struct regress_html *r, struct suite *suite, struct arena_scope *s)
{
	struct html *html = r->html;

	HTML_NODE(html, "tr") {
		VECTOR(struct run) runs = suite->runs;
		const struct regress_invocation *ri = r->invocations;
		size_t i;

		HTML_NODE(html, "td") {
			const char *href;

			href = cvsweb_url(suite->name, s);
			HTML_NODE_ATTR(html, "a", HTML_ATTR("class", "suite"),
			    HTML_ATTR("href", href))
				HTML_TEXT(html, suite->name);
		}

		VECTOR_SORT(runs, run_cmp);

		for (i = 0; i < VECTOR_LENGTH(runs); i++) {
			const struct run *run = &runs[i];

			/* Compensate for missing run(s). */
			for (; ri->time > run->time; ri++) {
				HTML_NODE(r->html, "td") {
					/* nothing */
				}
			}
			ri++;

			render_run(r, run);
		}
	}
}

static void
render_run(struct regress_html *r, const struct run *run)
{
	struct html *html = r->html;
	const char *status = run_status_str(run->status);

	HTML_NODE_ATTR(html, "td", HTML_ATTR("class", status)) {
		HTML_NODE_ATTR(html, "a",
		    HTML_ATTR("class", "status"), HTML_ATTR("href", run->log))
			HTML_TEXT(html, status);
	}
}

static const char *
cvsweb_url(const char *path, struct arena_scope *s)
{
	return arena_printf(s,
	    "https://cvsweb.openbsd.org/cgi-bin/cvsweb/src/regress/%s", path);
}

static enum duration_delta
duration_delta(int64_t a, int64_t b)
{
	int64_t threshold_s = 10ll * 60ll;
	int64_t abs, delta;

	delta = a - b;
	abs = delta < 0 ? -delta : delta;
	if (abs <= threshold_s)
		return NONE;
	return delta < 0 ? FASTER : SLOWER;
}

static int
is_run_status_failure(enum run_status status)
{
	switch (status) {
#define OP(s, failure) case s: return failure;
	FOR_RUN_STATUSES(OP)
#undef OP
	}
	return 0;
}

static const char *
run_status_str(enum run_status status)
{
	switch (status) {
#define OP(s, ...) case s: return #s;
	FOR_RUN_STATUSES(OP)
#undef OP
	}
	return "N/A";
}
