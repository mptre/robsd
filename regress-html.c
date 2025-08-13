#include "regress-html.h"

#include "config.h"

#include <sys/stat.h>

#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "libks/arena-buffer.h"
#include "libks/arena-vector.h"
#include "libks/arena.h"
#include "libks/buffer.h"
#include "libks/map.h"
#include "libks/vector.h"

#include "html.h"
#include "invocation.h"
#include "regress-log.h"
#include "step-exec.h"
#include "step.h"

#define FOR_RUN_STATUSES(OP)					\
	/* status  failure */					\
	OP(PASS,   0)						\
	OP(FAIL,   1)						\
	OP(XFAIL,  0)						\
	OP(XPASS,  1)						\
	OP(SKIP,   0)						\
	OP(NOTERM, 1)

enum suite_type {
	SUITE_UNKNOWN,
	SUITE_INFORMATIVE,
	SUITE_NON_REGRESS,
	SUITE_REGRESS,
};

#define OP(s, ...) s,
enum run_status {
	FOR_RUN_STATUSES(OP)
};
#undef OP

struct regress_html {
	VECTOR(struct regress_invocation)	 invocations;
	MAP(const char, *, struct suite)	 suites;
	const char				*output;
	struct html				*html;

	struct {
		struct arena_scope	*eternal_scope;
		struct arena		*scratch;
	} arena;
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

struct run {
	char		*log;
	int64_t		 time;
	int64_t		 exit;
	enum run_status	 status;
};

struct suite {
	const char		*name;
	enum suite_type		 type;
	int			 fail;
	VECTOR(struct run)	 runs;
};

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

static enum suite_type
categorize_suite(const char *name)
{
	if (strncmp(name, "../", 3) == 0) {
		/*
		 * Suite outside the regress directory, often dependencies that
		 * are not that interesting.
		 */
		return SUITE_NON_REGRESS;
	} else if (strcmp(name, "pkg-add") == 0) {
		/*
		 * Included since its outcome affects regress suites requiring
		 * certain packages.
		 */
		return SUITE_INFORMATIVE;
	} else if (strchr(name, '/') != NULL) {
		/*
		 * Note, the regress configuration cannot be used here as we
		 * might render runs referring to suites deleted from the
		 * configuration by now.
		 */
		return SUITE_REGRESS;
	} else {
		return SUITE_UNKNOWN;
	}
}

static struct suite *
find_suite(struct regress_html *r, const char *name, enum suite_type type)
{
	struct suite *suite;

	suite = MAP_FIND(r->suites, name);
	if (suite == NULL) {
		suite = MAP_INSERT(r->suites, name);
		suite->name = MAP_KEY(r->suites, suite);
		suite->type = type;
		ARENA_VECTOR_INIT(r->arena.eternal_scope, suite->runs, 1 << 8);
	}
	return suite;
}

static void
regress_html_free(void *arg)
{
	struct regress_html *r = arg;
	MAP_FREE(r->suites);
}

struct regress_html *
regress_html_alloc(const char *directory, struct arena *scratch,
    struct arena_scope *s)
{
	struct regress_html *r;

	r = arena_calloc(s, 1, sizeof(*r));
	ARENA_VECTOR_INIT(s, r->invocations, 1 << 5);
	if (MAP_INIT(r->suites))
		err(1, NULL);
	r->output = directory;
	r->arena.eternal_scope = s;
	r->arena.scratch = scratch;
	r->html = html_alloc(s);
	arena_cleanup(s, regress_html_free, r);
	return r;
}

static struct regress_invocation *
create_regress_invocation(struct regress_html *r, const char *arch,
    const char *date, int64_t time, int64_t duration)
{
	struct regress_invocation *ri = NULL;
	const char *path;

	arena_scope(r->arena.scratch, s);

	/*
	 * Create architecture output directory, could already have been created
	 * while handling a previous invocation.
	 */
	path = arena_sprintf(&s, "%s/%s", r->output, arch);
	if (mkdir(path, 0755) == -1 && errno != EEXIST) {
		warn("mkdir: %s", path);
		return NULL;
	}
	/* Create invocation output directory. */
	path = arena_sprintf(&s, "%s/%s/%s", r->output, arch, date);
	if (mkdir(path, 0755) == -1) {
		warn("mkdir: %s", path);
		return NULL;
	}

	ri = ARENA_VECTOR_CALLOC(r->invocations);
	ri->arch = arena_strdup(r->arena.eternal_scope, arch);
	ri->date = arena_strdup(r->arena.eternal_scope, date);
	ri->time = time;
	ri->duration.seconds = duration;

	ri->dmesg = arena_sprintf(r->arena.eternal_scope, "%s/%s/dmesg",
	    arch, date);
	ri->comment = arena_sprintf(r->arena.eternal_scope, "%s/%s/comment",
	    arch, date);
	ri->patches.path = arena_sprintf(r->arena.eternal_scope, "%s/%s/diff",
	    arch, date);

	return ri;
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

static int
copy_log(struct regress_html *r, const char *basename,
    const struct buffer *bf)
{
	const char *path;

	arena_scope(r->arena.scratch, s);

	path = arena_sprintf(&s, "%s/%s", r->output, basename);
	return write_log(path, bf);
}

static int
copy_files(struct regress_html *r, const struct regress_invocation *ri,
    const char *directory)
{
	struct buffer *bf;
	const char *path;
	int error = 0;

	arena_scope(r->arena.scratch, s);

	path = arena_sprintf(&s, "%s/dmesg", directory);
	bf = arena_buffer_read(&s, path);
	if (bf == NULL) {
		warn("%s", path);
	} else {
		if (copy_log(r, ri->dmesg, bf)) {
			error = 1;
			goto out;
		}
	}

	path = arena_sprintf(&s, "%s/comment", directory);
	bf = arena_buffer_read(&s, path);
	if (bf == NULL) {
		warn("%s", path);
	} else {
		if (copy_log(r, ri->comment, bf)) {
			error = 1;
			goto out;
		}
	}

out:
	return error;
}

static int
copy_patches(struct regress_html *r, struct regress_invocation *ri,
    const char *directory)
{
	struct invocation_state *is;
	const struct invocation_entry *entry;
	const char *path;
	int error = 0;
	int npatches = 0;

	arena_scope(r->arena.scratch, s);

	is = invocation_find(directory, "src.diff.*", &s);
	if (is == NULL)
		return 0;

	path = arena_sprintf(&s, "%s/%s", r->output, ri->patches.path);
	if (mkdir(path, 0755) == -1) {
		warn("mkdir: %s", path);
		error = 1;
		goto out;
	}
	while ((entry = invocation_walk(is)) != NULL) {
		struct buffer *bf;

		bf = arena_buffer_read(&s, entry->path);
		if (bf == NULL) {
			warn("%s", entry->path);
			error = 1;
			goto out;
		}
		path = arena_sprintf(&s, "%s/%s/%s",
		    r->output, ri->patches.path, entry->basename);
		error = write_log(path, bf);
		if (error) {
			error = 1;
			goto out;
		}
		npatches++;
	}

	error = 0;

out:
	invocation_free(is);
	return error ? -1 : npatches;
}

static int
parse_run_log(struct regress_html *r, const struct run *run,
    const char *src_path, const char *dst_path, enum run_status *status)
{
	struct buffer *bf;
	int error, nfail, nskip;

	if (access(src_path, R_OK) == -1) {
		warn("%s", src_path);
		return 1;
	}

	arena_scope(r->arena.scratch, s);

	if (run->exit == EX_TIMEOUT) {
		*status = NOTERM;
	} else if (run->exit != 0) {
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

	bf = arena_buffer_alloc(&s, 1 << 13);
	nfail = regress_log_parse(src_path, bf,
	    REGRESS_LOG_FAILED | REGRESS_LOG_XFAILED | REGRESS_LOG_XPASSED);
	nskip = regress_log_parse(src_path, bf,
	    REGRESS_LOG_SKIPPED | (nfail > 0 ? REGRESS_LOG_NEWLINE : 0));
	if (nfail > 0) {
		error = copy_log(r, dst_path, bf);
	} else if (!is_run_status_failure(*status) && nskip > 0) {
		error = copy_log(r, dst_path, bf);
	} else if (regress_log_trim(src_path, bf) > 0) {
		error = copy_log(r, dst_path, bf);
	} else {
		warnx("%s: failed to parse log", src_path);
		error = 1;
	}

	return error;
}

static int
parse_invocation(struct regress_html *r, const char *arch,
    const char *directory, const char *date)
{
	struct step_file *step_file;
	struct step *end, *steps;
	struct regress_invocation *ri;
	const char *step_path;
	int64_t duration, time;
	size_t i;
	int error = 0;
	int rv;

	arena_scope(r->arena.scratch, s);

	step_path = arena_sprintf(&s, "%s/step.csv", directory);
	step_file = steps_parse(step_path, &s);
	if (step_file == NULL)
		return 1;
	steps = steps_get(step_file);
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
	ri = create_regress_invocation(r, arch, date, time, duration);
	if (ri == NULL) {
		error = 1;
		goto out;
	}
	if (copy_files(r, ri, directory)) {
		error = 1;
		goto out;
	}
	if (invocation_has_tag(directory, "cvs", r->arena.scratch))
		ri->flags |= REGRESS_INVOCATION_CVS;
	rv = copy_patches(r, ri, directory);
	if (rv == -1) {
		error = 1;
		goto out;
	}
	ri->patches.count = rv;

	for (i = 0; i < VECTOR_LENGTH(steps); i++) {
		struct suite *suite;
		struct run *run;
		const char *log_path;
		enum run_status status;

		const char *name = step_get_field(&steps[i], "name")->str;
		enum suite_type type = categorize_suite(name);
		if (type == SUITE_UNKNOWN)
			continue;

		ri->total++;

		suite = find_suite(r, name, type);
		run = ARENA_VECTOR_CALLOC(suite->runs);
		run->log = arena_sprintf(r->arena.eternal_scope, "%s/%s/%s",
		    arch, ri->date, step_get_field(&steps[i], "log")->str);
		run->time = time;
		run->exit = step_get_field(&steps[i], "exit")->integer;

		log_path = arena_sprintf(&s, "%s/%s",
		    directory, step_get_field(&steps[i], "log")->str);
		if (parse_run_log(r, run, log_path, run->log, &status)) {
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
	steps_free(step_file);
	return error;
}

int
regress_html_parse(struct regress_html *r, const char *arch,
    const char *robsddir)
{
	const char *keepdir;
	struct invocation_state *is;
	const struct invocation_entry *entry;
	int error = 0;
	int ninvocations = 0;

	arena_scope(r->arena.scratch, s);

	keepdir = arena_sprintf(r->arena.eternal_scope, "%s/attic", robsddir);
	is = invocation_alloc(robsddir, keepdir, &s, INVOCATION_SORT_ASC);
	if (is == NULL) {
		error = 1;
		goto out;
	}
	while ((entry = invocation_walk(is)) != NULL) {
		if (parse_invocation(r, arch, entry->path, entry->basename)) {
			error = 1;
			goto out;
		}

		if (++ninvocations >= 2) {
			uint32_t n = VECTOR_LENGTH(r->invocations);
			r->invocations[n - 1].duration.delta = duration_delta(
			    r->invocations[n - 1].duration.seconds,
			    r->invocations[n - 2].duration.seconds);
		}
	}

	VECTOR_SORT(r->invocations, regress_invocation_cmp);

	MAP_ITERATOR(r->suites) it = {0};
	while (MAP_ITERATE(r->suites, &it)) {
		struct suite *suite = it.val;
		VECTOR_SORT(suite->runs, run_cmp);
	}

out:
	invocation_free(is);
	return error;
}

static struct suite **
sort_suites(struct regress_html *r, struct arena_scope *s)
{
	VECTOR(struct suite *) all;
	ARENA_VECTOR_INIT(s, all, 1 << 8);
	VECTOR(struct suite *) pass;
	ARENA_VECTOR_INIT(s, pass, 1 << 8);
	VECTOR(struct suite *) nonregress;
	ARENA_VECTOR_INIT(s, nonregress, 1 << 2);

	MAP_ITERATOR(r->suites) it = {0};
	while (MAP_ITERATE(r->suites, &it)) {
		struct suite *suite = it.val;
		if (suite->fail > 0)
			*ARENA_VECTOR_ALLOC(all) = suite;
		else if (suite->type == SUITE_INFORMATIVE ||
		    suite->type == SUITE_NON_REGRESS)
			*ARENA_VECTOR_ALLOC(nonregress) = suite;
		else
			*ARENA_VECTOR_ALLOC(pass) = suite;
	}

	VECTOR_SORT(all, suite_cmp);
	VECTOR_SORT(pass, suite_cmp);
	VECTOR_SORT(nonregress, suite_cmp);

	for (uint32_t i = 0; i < VECTOR_LENGTH(pass); i++)
		*ARENA_VECTOR_ALLOC(all) = pass[i];
	for (uint32_t i = 0; i < VECTOR_LENGTH(nonregress); i++)
		*ARENA_VECTOR_ALLOC(all) = nonregress[i];

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
	return arena_sprintf(s, "%dh%dm<span>%s</span>",
	    (int)hours, (int)minutes, arrows[ri->duration.delta]);
}

static const char *
render_rate(const struct regress_invocation *ri, struct arena_scope *s)
{
	float rate = 0;

	if (ri->total > 0)
		rate = 1 - (ri->fail / (float)ri->total);
	return arena_sprintf(s, "%d%%", (int)(rate * 100));
}

static void
render_pass_rates(struct regress_html *r)
{
	struct html *html = r->html;

	arena_scope(r->arena.scratch, s);

	HTML_NODE(html, "tr") {
		HTML_NODE(html, "th")
			HTML_TEXT(html, "pass rate");
		for (uint32_t i = 0; i < VECTOR_LENGTH(r->invocations); i++) {
			const struct regress_invocation *ri = &r->invocations[i];

			HTML_NODE_ATTR(html, "th", HTML_ATTR("class", "pass"))
				HTML_TEXT(html, render_rate(ri, &s));
		}
	}
}

static void
render_dates(struct regress_html *r)
{
	struct html *html = r->html;

	HTML_NODE(html, "tr") {
		HTML_NODE(html, "th")
			HTML_TEXT(html, "date");
		for (uint32_t i = 0; i < VECTOR_LENGTH(r->invocations); i++) {
			const struct regress_invocation *ri = &r->invocations[i];

			HTML_NODE_ATTR(html, "th", HTML_ATTR("class", "date"))
				HTML_TEXT(html, ri->date);
		}
	}
}

static void
render_durations(struct regress_html *r)
{
	struct html *html = r->html;

	arena_scope(r->arena.scratch, s);

	HTML_NODE(html, "tr") {
		HTML_NODE(html, "th")
			HTML_TEXT(html, "duration");
		for (uint32_t i = 0; i < VECTOR_LENGTH(r->invocations); i++) {
			const struct regress_invocation *ri = &r->invocations[i];

			HTML_NODE_ATTR(html, "th",
			    HTML_ATTR("class", "duration"))
				HTML_TEXT(html, render_duration(ri, &s));
		}
	}
}

static void
render_changelog(struct regress_html *r)
{
	struct html *html = r->html;

	HTML_NODE(html, "tr") {
		HTML_NODE(html, "th")
			HTML_TEXT(html, "changelog");
		for (uint32_t i = 0; i < VECTOR_LENGTH(r->invocations); i++) {
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
render_patches(struct regress_html *r)
{
	struct html *h = r->html;

	arena_scope(r->arena.scratch, s);

	HTML_NODE(h, "tr") {
		HTML_NODE(h, "th")
			HTML_TEXT(h, "patches");
		for (uint32_t i = 0; i < VECTOR_LENGTH(r->invocations); i++) {
			const struct regress_invocation *ri = &r->invocations[i];

			HTML_NODE_ATTR(h, "th", HTML_ATTR("class", "patch")) {
				if (ri->patches.count > 0) {
					const char *text;

					text = arena_sprintf(&s, "patches (%d)",
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
		HTML_NODE(html, "th")
			HTML_TEXT(html, "architecture");
		for (uint32_t i = 0; i < VECTOR_LENGTH(r->invocations); i++) {
			const struct regress_invocation *ri = &r->invocations[i];

			HTML_NODE_ATTR(html, "th", HTML_ATTR("class", "arch")) {
				HTML_NODE_ATTR(html, "a",
				    HTML_ATTR("href", ri->dmesg))
					HTML_TEXT(html, ri->arch);
			}
		}
	}
}

static const char *
cvsweb_url(const char *path, struct arena_scope *s)
{
	return arena_sprintf(s,
	    "https://cvsweb.openbsd.org/cgi-bin/cvsweb/src/regress/%s", path);
}

static const char *
github_url(const char *step_name, struct arena_scope *s)
{
	return arena_sprintf(s,
	    "https://github.com/mptre/robsd/blob/master/robsd-regress-%s.sh",
	    step_name);
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

static void
render_suite(struct regress_html *r, const struct suite *suite)
{
	struct html *html = r->html;

	arena_scope(r->arena.scratch, s);

	HTML_NODE(html, "tr") {
		HTML_NODE(html, "td") {
			const char *href = suite->type == SUITE_INFORMATIVE ?
			    github_url(suite->name, &s) :
			    cvsweb_url(suite->name, &s);
			HTML_NODE_ATTR(html, "a",
			    HTML_ATTR("class", "suite"),
			    HTML_ATTR("href", href))
				HTML_TEXT(html, suite->name);
		}

		const struct regress_invocation *ri = r->invocations;
		VECTOR(const struct run) runs = suite->runs;
		for (uint32_t i = 0; i < VECTOR_LENGTH(runs); i++) {
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

int
regress_html_render(struct regress_html *r)
{
	struct html *html = r->html;

	arena_scope(r->arena.scratch, s);

	HTML_HEAD(html) {
		HTML_NODE(html, "title")
			HTML_TEXT(html, "OpenBSD regress");
	}

	HTML_NODE(html, "h1")
		HTML_TEXT(html, "OpenBSD regress latest test results");

	VECTOR(struct suite *) suites = sort_suites(r, &s);
	HTML_NODE(html, "table") {
		HTML_NODE(html, "thead") {
			render_pass_rates(r);
			render_dates(r);
			render_durations(r);
			render_changelog(r);
			render_patches(r);
			render_arches(r);
		}

		HTML_NODE(html, "tbody") {
			for (uint32_t i = 0; i < VECTOR_LENGTH(suites); i++)
				render_suite(r, suites[i]);
		}
	}

	const char *path = arena_sprintf(&s, "%s/index.html", r->output);
	return html_write(r->html, path);
}
