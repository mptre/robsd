#include "regress-html.h"

#include "config.h"

#include <sys/types.h>
#include <sys/stat.h>

#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include "alloc.h"
#include "buffer.h"
#include "cdefs.h"
#include "html.h"
#include "invocation.h"
#include "regress-log.h"
#include "step.h"
#include "vector.h"

/*
 * cppcheck is having a hard time dealing with all macro gymnastics going on in
 * this file.
 */
#ifndef NO_UTHASH
#include "uthash.h"
#endif

struct regress_html {
	VECTOR(struct regress_invocation)	 invocations;
	struct suite				*suites;
	const char				*output;
	struct html				*html;
	struct buffer				*scratch;
	struct buffer				*path;
};

struct regress_invocation {
	char		*arch;
	char		*date;
	char		*dmesg;
	char		*comment;
	char		*patches;
	int64_t		 time;
	int		 total;
	int		 fail;
	unsigned int	 flags;
#define REGRESS_INVOCATION_CVS		0x00000001u
#define REGRESS_INVOCATION_PATCH	0x00000002u
};

struct run {
	char	*log;
	int64_t	 time;
	enum run_status {
		PASS,
		FAIL,
		XFAIL,
		SKIP,
	} status;
};

struct suite {
	char			*name;
	int			 fail;
	VECTOR(struct run)	 runs;
	UT_hash_handle		 hh;
};

static int				  parse_invocation(struct regress_html *,
    const char *, const char *);
static struct regress_invocation	 *create_regress_invocation(
    struct regress_html *, const char *, const char *, int64_t);
static int				  create_directories(
    struct regress_html *, struct regress_invocation *, const char *);
static int				  create_patches(struct regress_html *,
    struct regress_invocation *, const char *);
static struct suite			 *find_suite(struct regress_html *,
    const char *);
static struct suite			**sort_suites(struct suite *);
static const char			 *pass_rate(struct regress_html *,
    const struct regress_invocation *);

static int	regress_invocation_cmp(const struct regress_invocation *,
    const struct regress_invocation *);
static int	run_cmp(const struct run *, const struct run *);
static int	suite_cmp(struct suite *const *, struct suite *const *);

static int	create_log(struct regress_html *,
    const struct run *, const struct buffer *);
static int	write_log(const char *, const struct buffer *);

static void	render_pass_rates(struct regress_html *);
static void	render_dates(struct regress_html *);
static void	render_changelog(struct regress_html *);
static void	render_patches(struct regress_html *);
static void	render_arches(struct regress_html *);
static void	render_suite(struct regress_html *,
    struct suite *);
static void	render_run(struct regress_html *,
    const struct run *);

static const char	*cvsweb_url(struct buffer *, const char *);
static int		 dateformat(int64_t, char *, size_t);
static const char	*joinpath(struct buffer *, const char *, ...)
	__attribute__((__format__(printf, 2, 3)));
static const char	*strstatus(enum run_status);

struct regress_html *
regress_html_alloc(const char *directory)
{
	struct regress_html *r;

	r = ecalloc(1, sizeof(*r));
	if (VECTOR_INIT(r->invocations) == NULL)
		err(1, NULL);
	r->output = directory;
	r->html = html_alloc();
	r->scratch = buffer_alloc(1 << 10);
	if (r->scratch == NULL)
		err(1, NULL);
	r->path = buffer_alloc(PATH_MAX);
	if (r->path == NULL)
		err(1, NULL);
	return r;
}

void
regress_html_free(struct regress_html *r)
{
	struct suite *suite, *tmp;

	if (r == NULL)
		return;

	while (!VECTOR_EMPTY(r->invocations)) {
		struct regress_invocation *ri;

		ri = VECTOR_POP(r->invocations);
		free(ri->arch);
		free(ri->date);
		free(ri->dmesg);
		free(ri->comment);
		free(ri->patches);
	}
	VECTOR_FREE(r->invocations);
	HASH_ITER(hh, r->suites, suite, tmp) {
		free(suite->name);
		while (!VECTOR_EMPTY(suite->runs)) {
			struct run *run;

			run = VECTOR_POP(suite->runs);
			free(run->log);
		}
		VECTOR_FREE(suite->runs);
		HASH_DELETE(hh, r->suites, suite);
		free(suite);
	}
	html_free(r->html);
	buffer_free(r->scratch);
	buffer_free(r->path);
	free(r);
}

int
regress_html_parse(struct regress_html *r, const char *arch,
    const char *robsddir)
{
	struct buffer *bf;
	const char *keepdir, *path;
	struct invocation_state *is;
	int error = 0;

	bf = buffer_alloc(PATH_MAX);
	if (bf == NULL)
		err(1, NULL);
	keepdir = joinpath(bf, "%s/attic", robsddir);
	is = invocation_alloc(robsddir, keepdir);
	if (is == NULL) {
		error = 1;
		goto out;
	}
	while ((path = invocation_walk(is)) != NULL) {
		if (parse_invocation(r, arch, path)) {
			error = 1;
			goto out;
		}
	}

out:
	invocation_free(is);
	buffer_free(bf);
	return error;
}

int
regress_html_render(struct regress_html *r)
{
	struct suite **suites;
	struct html *html = r->html;
	const char *path;

	VECTOR_SORT(r->invocations, regress_invocation_cmp);

	HTML_HEAD(html) {
		HTML_NODE(html, "title")
			HTML_TEXT(html, "OpenBSD regress");
	}

	HTML_NODE(html, "h1")
		HTML_TEXT(html, "OpenBSD regress latest test results");

	suites = sort_suites(r->suites);
	HTML_NODE(html, "table") {
		size_t i;

		HTML_NODE(html, "thead") {
			render_pass_rates(r);
			render_dates(r);
			render_changelog(r);
			render_patches(r);
			render_arches(r);
		}

		HTML_NODE(html, "tbody") {
			for (i = 0; i < VECTOR_LENGTH(suites); i++)
				render_suite(r, suites[i]);
		}
	}
	VECTOR_FREE(suites);

	path = joinpath(r->path, "%s/index.html", r->output);
	/* coverity[leaked_storage: FALSE] */
	return html_write(r->html, path);
}

static int
parse_invocation(struct regress_html *r, const char *arch,
    const char *directory)
{
	char date[16];
	struct buffer *dmesg = NULL;
	struct buffer *scratch = r->scratch;
	struct step *steps;
	struct regress_invocation *ri;
	const char *path;
	int64_t time;
	size_t i;
	int error = 0;

	path = joinpath(r->path, "%s/step.csv", directory);
	steps = steps_parse(path);
	if (steps == NULL)
		return 1;
	if (VECTOR_EMPTY(steps)) {
		warnx("%s: no steps found", path);
		error = 1;
		goto out;
	}

	time = step_get_field(&steps[0], "time")->integer;
	if (dateformat(time, date, sizeof(date))) {
		error = 1;
		goto out;
	}

	ri = create_regress_invocation(r, arch, date, time);
	if (create_directories(r, ri, directory)) {
		error = 1;
		goto out;
	}
	if (invocation_has_tag(directory, "cvs")) {
		ri->flags |= REGRESS_INVOCATION_CVS;
		if (create_patches(r, ri, directory))
			ri->flags |= REGRESS_INVOCATION_PATCH;
	}

	for (i = 0; i < VECTOR_LENGTH(steps); i++) {
		struct suite *suite;
		struct run *run;
		const char *log, *name;
		int exit;

		name = step_get_field(&steps[i], "name")->str;
		if (strchr(name, '/') == 0)
			continue;

		ri->total++;

		exit = step_get_field(&steps[i], "exit")->integer;
		log = step_get_field(&steps[i], "log")->str;

		suite = find_suite(r, name);
		run = VECTOR_CALLOC(suite->runs);
		if (run == NULL)
			err(1, NULL);
		buffer_reset(scratch);
		buffer_printf(scratch, "%s/%s/%s", arch, date, log);
		run->log = estrdup(buffer_get_ptr(scratch));
		run->time = time;
		buffer_reset(scratch);

		path = joinpath(r->path, "%s/%s", directory, log);
		if (exit != 0) {
			regress_log_parse(path, scratch, REGRESS_LOG_FAILED);
			ri->fail++;
			suite->fail++;
			run->status = FAIL;
			if (create_log(r, run, scratch)) {
				error = 1;
				goto out;
			}
			continue;
		}

		if (regress_log_parse(path, scratch, REGRESS_LOG_XFAILED) > 0) {
			buffer_reset(scratch);
			regress_log_parse(path, scratch,
			    REGRESS_LOG_XFAILED | REGRESS_LOG_SKIPPED);
			run->status = XFAIL;
			if (create_log(r, run, scratch)) {
				error = 1;
				goto out;
			}
			continue;
		}

		buffer_reset(scratch);
		if (regress_log_parse(path, scratch, REGRESS_LOG_SKIPPED) > 0) {
			run->status = SKIP;
			if (create_log(r, run, scratch)) {
				error = 1;
				goto out;
			}
			continue;
		}

		buffer_reset(scratch);
		if (regress_log_trim(path, scratch)) {
			run->status = PASS;
			if (create_log(r, run, scratch)) {
				error = 1;
				goto out;
			}
		}
	}

out:
	buffer_free(dmesg);
	steps_free(steps);
	return error;
}

static struct regress_invocation *
create_regress_invocation(struct regress_html *r, const char *arch,
    const char *date, int64_t time)
{
	struct regress_invocation *ri;
	const char *comment, *dmesg, *patches;

	ri = VECTOR_CALLOC(r->invocations);
	if (ri == NULL)
		err(1, NULL);
	ri->arch = estrdup(arch);
	ri->date = estrdup(date);

	dmesg = joinpath(r->path, "%s/%s/dmesg", arch, date);
	ri->dmesg = estrdup(dmesg);

	comment = joinpath(r->path, "%s/%s/comment", arch, date);
	ri->comment = estrdup(comment);

	patches = joinpath(r->path, "%s/%s/diff", arch, date);
	ri->patches = estrdup(patches);

	ri->time = time;

	return ri;
}

static int
create_directories(struct regress_html *r, struct regress_invocation *ri,
    const char *directory)
{
	struct buffer *bf = NULL;
	const char *path;
	int error = 0;

	path = joinpath(r->path, "%s/%s", r->output, ri->arch);
	if (mkdir(path, 0755) == -1 && errno != EEXIST) {
		warn("mkdir: %s", path);
		error = 1;
		goto out;
	}
	path = joinpath(r->path, "%s/%s/%s", r->output, ri->arch, ri->date);
	if (mkdir(path, 0755) == -1 && errno != EEXIST) {
		warn("mkdir: %s", path);
		error = 1;
		goto out;
	}

	path = joinpath(r->path, "%s/dmesg", directory);
	bf = buffer_read(path);
	if (bf == NULL) {
		warn("%s", path);
	} else {
		path = joinpath(r->path, "%s/%s", r->output, ri->dmesg);
		if (write_log(path, bf)) {
			error = 1;
			goto out;
		}
	}
	buffer_free(bf);

	path = joinpath(r->path, "%s/comment", directory);
	bf = buffer_read(path);
	if (bf == NULL) {
		warn("%s", path);
	} else {
		path = joinpath(r->path, "%s/%s", r->output, ri->comment);
		if (write_log(path, bf)) {
			error = 1;
			goto out;
		}
	}

out:
	buffer_free(bf);
	return error;
}

static int
create_patches(struct regress_html *r, struct regress_invocation *ri,
    const char *directory)
{
	struct invocation_entry *patches;
	const char *path;
	size_t i;
	int error = 0;

	patches = invocation_find(directory, "src.diff.*");
	if (patches == NULL)
		return 0;

	path = joinpath(r->path, "%s/%s", r->output, ri->patches);
	if (mkdir(path, 0755) == -1) {
		warn("mkdir: %s", path);
		error = 1;
		goto out;
	}
	for (i = 0; i < VECTOR_LENGTH(patches); i++) {
		struct buffer *bf;

		bf = buffer_read(patches[i].path);
		if (bf == NULL) {
			warn("%s", patches[i].path);
			error = 1;
			goto out;
		}
		path = joinpath(r->path, "%s/%s/%s",
		    r->output, ri->patches, patches[i].basename);
		error = write_log(path, bf);
		buffer_free(bf);
		if (error) {
			error = 1;
			goto out;
		}
	}

out:
	invocation_find_free(patches);
	/* coverity[leaked_storage: FALSE] */
	return error ? 0 : 1;
}

static struct suite *
find_suite(struct regress_html *r, const char *name)
{
	struct suite *suite;

	HASH_FIND_STR(r->suites, name, suite);
	if (suite == NULL) {
		suite = ecalloc(1, sizeof(*suite));
		suite->name = estrdup(name);
		if (VECTOR_INIT(suite->runs) == NULL)
			err(1, NULL);
		HASH_ADD_STR(r->suites, name, suite);
	}
	return suite;
}

static struct suite **
sort_suites(struct suite *suites)
{
	VECTOR(struct suite *) all;
	VECTOR(struct suite *) pass;
	struct suite *suite, *tmp;
	size_t i;

	if (VECTOR_INIT(all) == NULL)
		err(1, NULL);
	if (VECTOR_INIT(pass) == NULL)
		err(1, NULL);

	HASH_ITER(hh, suites, suite, tmp) {
		if (suite->fail > 0)
			*VECTOR_ALLOC(all) = suite;
		else
			*VECTOR_ALLOC(pass) = suite;
	}
	VECTOR_SORT(all, suite_cmp);
	for (i = 0; i < VECTOR_LENGTH(pass); i++)
		*VECTOR_ALLOC(all) = pass[i];
	VECTOR_FREE(pass);
	return all;
}

static const char *
pass_rate(struct regress_html *r, const struct regress_invocation *ri)
{
	struct buffer *bf = r->scratch;
	float rate = 0;

	if (ri->total > 0)
		rate = 1 - (ri->fail / (float)ri->total);
	buffer_reset(bf);
	buffer_printf(bf, "%d%%", (int)(rate * 100));
	return buffer_get_ptr(bf);
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
	return 0;
}

static int
create_log(struct regress_html *r, const struct run *run,
    const struct buffer *bf)
{
	const char *path;

	path = joinpath(r->path, "%s/%s", r->output, run->log);
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
render_pass_rates(struct regress_html *r)
{
	struct html *html = r->html;

	HTML_NODE(html, "tr") {
		size_t i;

		HTML_NODE(html, "th")
			HTML_TEXT(html, "pass rate");
		for (i = 0; i < VECTOR_LENGTH(r->invocations); i++) {
			const struct regress_invocation *ri = &r->invocations[i];

			HTML_NODE_ATTR(html, "th", HTML_ATTR("class", "rate"))
				HTML_TEXT(html, pass_rate(r, ri));
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
					    HTML_ATTR("href", ri->comment)) {
						HTML_TEXT(html,
						    "cvs");
					}
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

	HTML_NODE(h, "tr") {
		size_t i;

		HTML_NODE(h, "th")
			HTML_TEXT(h, "patches");
		for (i = 0; i < VECTOR_LENGTH(r->invocations); i++) {
			const struct regress_invocation *ri = &r->invocations[i];

			HTML_NODE_ATTR(h, "th", HTML_ATTR("class", "patch")) {
				if (ri->flags & REGRESS_INVOCATION_PATCH) {
					HTML_NODE_ATTR(h, "a",
					    HTML_ATTR("href", ri->patches)) {
						HTML_TEXT(h,
						    "patches");
					}
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
				    HTML_ATTR("href", ri->dmesg)) {
					HTML_TEXT(html,
					    ri->arch);
				}
			}
		}
	}
}

static void
render_suite(struct regress_html *r, struct suite *suite)
{
	struct html *html = r->html;

	HTML_NODE(html, "tr") {
		VECTOR(struct run) runs = suite->runs;
		const struct regress_invocation *ri = r->invocations;
		size_t i;

		HTML_NODE(html, "td") {
			const char *href;

			href = cvsweb_url(r->scratch, suite->name);
			HTML_NODE_ATTR(html, "a", HTML_ATTR("class", "suite"),
			    HTML_ATTR("href", href)) {
				HTML_TEXT(html,
				    suite->name);
			}
		}

		VECTOR_SORT(runs, run_cmp);

		for (i = 0; i < VECTOR_LENGTH(runs); i++) {
			const struct run *run = &runs[i];

			/* Compensate for missing run(s). */
			for (; ri->time > run->time; ri++) {
				/* NOLINTNEXTLINE(bugprone-suspicious-semicolon) */
				HTML_NODE(r->html, "td");
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
	const char *status = strstatus(run->status);

	HTML_NODE_ATTR(html, "td", HTML_ATTR("class", status)) {
		HTML_NODE_ATTR(html, "a",
		    HTML_ATTR("class", "status"), HTML_ATTR("href", run->log)) {
			HTML_TEXT(html,
			    status);
		}
	}
}

static const char *
cvsweb_url(struct buffer *bf, const char *path)
{
	buffer_reset(bf);
	buffer_printf(bf,
	    "https://cvsweb.openbsd.org/cgi-bin/cvsweb/src/regress/%s", path);
	return buffer_get_ptr(bf);
}

static int
dateformat(int64_t ts, char *buf, size_t bufsiz)
{
	struct tm tm;
	time_t time = ts;

	if (gmtime_r(&time, &tm) == NULL) {
		warn("gmtime_r");
		return 1;
	}
	if (strftime(buf, bufsiz, "%Y-%m-%d", &tm) == 0) {
		warn("strftime");
		return 1;
	}
	return 0;
}

static const char *
joinpath(struct buffer *bf, const char *fmt, ...)
{
	va_list ap;

	buffer_reset(bf);
	va_start(ap, fmt);
	buffer_vprintf(bf, fmt, ap);
	va_end(ap);
	return buffer_get_ptr(bf);
}

static const char *
strstatus(enum run_status status)
{
	switch (status) {
	case PASS:
		return "PASS";
	case FAIL:
		return "FAIL";
	case XFAIL:
		return "XFAIL";
	case SKIP:
		return "SKIP";
	}
	return "N/A";
}
