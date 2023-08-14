#include "report.h"

#include "config.h"

#include <sys/stat.h>

#include <err.h>
#include <errno.h>
#include <fnmatch.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "libks/arena.h"
#include "libks/buffer.h"
#include "libks/vector.h"

#include "cdefs.h"
#include "conf.h"
#include "invocation.h"
#include "regress-log.h"
#include "step.h"

struct report_context {
	ARENA		*arena;
	const char	*builddir;
	const char	*prev_builddir;
	struct config	*config;
	struct step	*steps;
	struct buffer	*out;
	enum robsd_mode	 mode;
};

static int	threshold_duration_s = 60;
static size_t	threshold_size_b = (size_t)(1024 * 100);
static size_t	threshold_size_ramdisk_b = (size_t)1024;

static void
buffer_trim_lines(struct buffer *bf)
{
	const char *buf;
	size_t buflen;

	buf = buffer_get_ptr(bf);
	buflen = buffer_get_len(bf);
	for (; buflen > 0 && buf[buflen - 1] == '\n'; buflen--)
		buffer_pop(bf, 1);
}

static int
format_file(struct report_context *r, const char *path)
{
	struct buffer *bf;

	bf = buffer_read(path);
	if (bf == NULL) {
		warn("%s", path);
		return 1;
	}
	buffer_trim_lines(bf);
	buffer_puts(r->out, buffer_get_ptr(bf), buffer_get_len(bf));
	buffer_putc(r->out, '\n');
	buffer_free(bf);
	return 0;
}

static const char *
last_lines(const char *str, size_t len, size_t *outlen, unsigned int nlines)
{
	size_t oldlen = len;

	for (; nlines > 0; nlines--) {
		for (; len > 0 && str[len - 1] == '\n'; len--)
			continue;
		for (; len > 0 && str[len - 1] != '\n'; len--)
			continue;
		if (len == 0)
			break;
	}
	*outlen = oldlen - len;
	return &str[len];
}

static const char *
previous_builddir(struct config *config, const char *builddir,
    struct arena_scope *s)
{
	const struct invocation_entry *entry;
	struct invocation_state *is = NULL;
	const char *prev_builddir = NULL;
	char *keepdir = NULL;
	char *robsddir = NULL;

	robsddir = config_interpolate_str(config, "${robsddir}");
	if (robsddir == NULL)
		goto out;
	keepdir = config_interpolate_str(config, "${keep-dir}");
	if (keepdir == NULL)
		goto out;
	is = invocation_alloc(robsddir, keepdir, INVOCATION_SORT_DESC);
	if (is == NULL)
		goto out;
	while ((entry = invocation_walk(is)) != NULL) {
		if (strcmp(entry->path, builddir) == 0)
			continue;

		prev_builddir = arena_strdup(s, entry->path);
		break;
	}

out:
	free(keepdir);
	free(robsddir);
	invocation_free(is);
	return prev_builddir;
}

static const char *
step_get_log_path(struct report_context *r, const struct step *step,
    struct arena_scope *s)
{
	const char *log;

	log = step_get_field(step, "log")->str;
	if (log[0] == '\0')
		return NULL;
	return arena_printf(s, "%s/%s", r->builddir, log);
}

static int
report_cvs_log(struct report_context *r)
{
	SCOPE s = arena_scope(r->arena);
	struct {
		enum robsd_mode	 mode;
		const char	*filename;
	} paths[] = {
		{ CONFIG_ROBSD,		"cvs-src-up.log" },
		{ CONFIG_ROBSD,		"cvs-src-ci.log" },
		{ CONFIG_ROBSD,		"cvs-xenocara-up.log" },
		{ CONFIG_ROBSD,		"cvs-xenocara-ci.log" },
		{ CONFIG_ROBSD_PORTS,	"cvs-ports-up.log" },
		{ CONFIG_ROBSD_PORTS,	"cvs-ports-ci.log" },
	};
	size_t npaths = sizeof(paths) / sizeof(paths[0]);
	size_t i;
	int ncvs = 0;

	buffer_putc(r->out, '\n');

	for (i = 0; i < npaths; i++) {
		const char *path;

		if (paths[i].mode != r->mode)
			continue;

		path = arena_printf(&s, "%s/tmp/%s",
		    r->builddir, paths[i].filename);
		if (ncvs++ > 0)
			buffer_putc(r->out, '\n');
		if (format_file(r, path))
			return -1;
	}

	return 1;
}

static const char *
cross_report_subject(struct report_context *r, struct arena_scope *s)
{
	struct buffer *bf;
	const char *subject, *target_path;
	char *machine, *p, *target;

	target_path = arena_printf(s, "%s/target", r->builddir);
	bf = buffer_read(target_path);
	if (bf == NULL) {
		warn("%s", target_path);
		return NULL;
	}
	target = buffer_str(bf);
	p = strchr(target, '\n');
	if (p != NULL)
		*p = '\0';
	machine = config_interpolate_str(r->config, "${machine}");
	subject = arena_printf(s, " %s.%s: ",
	    machine != NULL ? machine : "", target);
	free(machine);
	free(target);
	buffer_free(bf);
	return subject;
}

static int
ports_report_skip_step(struct report_context *UNUSED(r),
    const struct step *step)
{
	const char *name;

	name = step_get_field(step, "name")->str;
	if (strcmp(name, "cvs") == 0)
		return 0;
	if (strcmp(name, "dpb") == 0)
		return 0;
	return 1;
}

static int
ports_report_step_log(struct report_context *r, const struct step *step)
{
	SCOPE s = arena_scope(r->arena);
	const char *name;

	name = step_get_field(step, "name")->str;
	if (strcmp(name, "cvs") == 0)
		return report_cvs_log(r);
	if (strcmp(name, "dpb") == 0) {
		const char *path;

		path = arena_printf(&s, "%s/tmp/packages.diff", r->builddir);
		if (step_get_field(step, "exit")->integer == 0) {
			buffer_putc(r->out, '\n');
			return format_file(r, path) ? -1 : 1;
		}
	}
	return 0;
}

static int
is_regress_quiet(struct report_context *r, const char *name)
{
	SCOPE s = arena_scope(r->arena);
	const char *quiet;

	quiet = arena_printf(&s, "regress-%s-quiet", name);
	return config_find(r->config, quiet) != NULL;
}

static int
regress_report_skip_step(struct report_context *r, const struct step *step)
{
	SCOPE s = arena_scope(r->arena);
	const char *log_path, *name;

	name = step_get_field(step, "name")->str;
	if (strchr(name, '/') == NULL)
		return 1;
	if (is_regress_quiet(r, name))
		return 1;

	log_path = step_get_log_path(r, step, &s);
	if (regress_log_peek(log_path,
	    REGRESS_LOG_SKIPPED | REGRESS_LOG_XFAILED) > 0)
		return 0;
	return 1;
}

static const char *
regress_report_status(struct report_context *r, struct arena_scope *s)
{
	size_t nsteps = VECTOR_LENGTH(r->steps);
	size_t i;
	int nfailures = 0;

	for (i = 0; i < nsteps; i++) {
		if (step_get_field(&r->steps[i], "exit")->integer != 0)
			nfailures++;
	}
	if (nfailures > 0) {
		return arena_printf(s, "%d failure%s",
		    nfailures, nfailures > 1 ? "s" : "");
	}
	return "ok";
}

static int
regress_report_step_log(struct report_context *r, const struct step *step)
{
	SCOPE s = arena_scope(r->arena);
	struct buffer *bf;
	const char *log_path, *name;
	unsigned int regress_log_flags;
	int rv = 0;

	bf = buffer_alloc(1 << 20);
	if (bf == NULL)
		err(1, NULL);

	name = step_get_field(step, "name")->str;
	log_path = step_get_log_path(r, step, &s);
	regress_log_flags = REGRESS_LOG_ERROR | REGRESS_LOG_FAILED |
	    REGRESS_LOG_XPASSED;
	if (!is_regress_quiet(r, name))
		regress_log_flags |= REGRESS_LOG_SKIPPED | REGRESS_LOG_XFAILED;
	rv = regress_log_parse(log_path, bf, regress_log_flags);
	if (rv > 0) {
		buffer_putc(r->out, '\n');
		buffer_puts(r->out, buffer_get_ptr(bf), buffer_get_len(bf));
	}

	buffer_free(bf);
	return rv;
}

static const char *
report_mode(const struct report_context *r)
{
	return robsd_mode_str(r->mode);
}

static const char *
report_hostname(struct arena_scope *s)
{
	char *dot, *name;
	size_t namelen;
	long max;

	max = sysconf(_SC_HOST_NAME_MAX);
	if (max == -1) {
		warn("sysconf");
		return NULL;
	}
	namelen = (size_t)max + 1;
	name = arena_malloc(s, namelen);
	if (gethostname(name, namelen) == -1) {
		warn("gethostname");
		return NULL;
	}
	dot = strchr(name, '.');
	if (dot != NULL)
		*dot = '\0';
	return name;
}

static const char *
report_status(struct report_context *r, struct arena_scope *s)
{
	size_t nsteps;

	if (r->mode == CONFIG_ROBSD_REGRESS)
		return regress_report_status(r, s);

	/*
	 * All other robsd utilities halts if a step failed, only bother
	 * checking the last non-skipped step.
	 */
	nsteps = VECTOR_LENGTH(r->steps);
	if (nsteps == 0)
		goto ok;
	for (;;) {
		const struct step *step;
		const char *name;

		if (nsteps == 0)
			break;
		step = &r->steps[--nsteps];
		if (step_get_field(step, "skip")->integer == 1)
			continue;
		if (step_get_field(step, "exit")->integer == 0)
			break;

		name = step_get_field(step, "name")->str;
		return arena_printf(s, "failed in %s", name);
	}

ok:
	return "ok";
}

static int
report_subject(struct report_context *r)
{
	SCOPE s = arena_scope(r->arena);
	const char *status_prefix = " ";
	const char *hostname, *mode, *status;

	mode = report_mode(r);
	hostname = report_hostname(&s);
	if (hostname == NULL)
		return 1;
	if (r->mode == CONFIG_ROBSD_CROSS)
		status_prefix = cross_report_subject(r, &s);
	status = report_status(r, &s);
	buffer_printf(r->out, "Subject: %s: %s:%s%s\n\n",
	    mode, hostname, status_prefix, status);
	return 0;
}

static int64_t
total_duration(struct report_context *r)
{
	int64_t duration = 0;
	size_t i, nsteps;

	nsteps = VECTOR_LENGTH(r->steps);
	for (i = 0; i < nsteps; i++) {
		const struct step *step = &r->steps[i];

		if (step_get_field(step, "skip")->integer == 1)
			continue;
		duration += step_get_field(step, "duration")->integer;
	}
	return duration;
}

static const char *
format_duration(int64_t duration, struct arena_scope *s)
{
	int64_t hours, minutes, seconds;

	hours = duration / 3600;
	duration %= 3600;
	minutes = duration / 60;
	duration %= 60;
	seconds = duration;
	return arena_printf(s, "%02d:%02d:%02d",
	    (int)hours, (int)minutes, (int)seconds);
}

static const char *
format_duration_and_delta(int64_t duration, int64_t delta,
    int64_t delta_threshold, struct arena_scope *s)
{
	int64_t delta_abs;

	if (delta == 0)
		return format_duration(duration, s);

	delta_abs = delta < 0 ? -delta : delta;
	if (delta_abs <= delta_threshold)
		return format_duration(duration, s);

	return arena_printf(s, "%s (%c%s)",
	    format_duration(duration, s),
	    delta < 0 ? '-' : '+',
	    format_duration(delta_abs, s));
}

static int
report_comment(struct report_context *r)
{
	SCOPE s = arena_scope(r->arena);
	struct buffer *bf;
	const char *path;

	path = arena_printf(&s, "%s/comment", r->builddir);
	bf = buffer_read(path);
	if (bf == NULL) {
		if (errno == ENOENT)
			return 0;
		warn("%s", path);
		return 1;
	}
	buffer_printf(r->out, "> comment\n");
	buffer_trim_lines(bf);
	buffer_puts(r->out, buffer_get_ptr(bf), buffer_get_len(bf));
	buffer_putc(r->out, '\n');
	buffer_putc(r->out, '\n');
	buffer_free(bf);
	return 0;
}

static void
report_stats_duration(struct report_context *r, struct arena_scope *s)
{
	const struct step *end;
	int64_t delta, duration;

	end = steps_find_by_name(r->steps, "end");
	if (end != NULL) {
		duration = step_get_field(end, "duration")->integer;
		delta = step_get_field(end, "delta")->integer;
	} else {
		duration = total_duration(r);
		delta = duration;
	}
	buffer_printf(r->out, "Duration: %s\n",
	    format_duration_and_delta(duration, delta,
	    threshold_duration_s, s));
}

static const char *
format_size(size_t size, struct arena_scope *s)
{
	const char *prefix = "";
	double div = 1;

	if (size >= (size_t)(1024 * 1024)) {
		div = 1024 * 1024;
		prefix = "M";
	} else if (size >= (size_t)1024) {
		div = 1024;
		prefix = "K";
	}
	return arena_printf(s, "%.01f%s", size / div, prefix);
}

static int
size_cmp(const char *const *a, const char *const *b)
{
	return strcmp(*a, *b);
}

static int
report_stats_sizes(struct report_context *r)
{
	SCOPE s = arena_scope(r->arena);
	VECTOR(const char *) sizes;
	const struct invocation_entry *entry;
	struct invocation_state *is;
	const char *directory;
	size_t i;

	if (r->prev_builddir == NULL)
		return 0;

	if (VECTOR_INIT(sizes))
		err(1, NULL);

	directory = arena_printf(&s, "%s/rel", r->builddir);
	is = invocation_find(directory, "*");
	if (is == NULL)
		goto out;
	while ((entry = invocation_walk(is)) != NULL) {
		struct stat prev_st, st;
		const char **dst;
		const char *prev_path, *str;
		size_t delta_abs, size;
		off_t delta;

		if (fnmatch("*.diff.[[:digit:]]*", entry->basename, 0) == 0)
			continue;

		prev_path = arena_printf(&s, "%s/rel/%s",
		    r->prev_builddir, entry->basename);
		if (stat(prev_path, &prev_st) == -1) {
			warn("stat: %s", prev_path);
			continue;
		}

		if (stat(entry->path, &st) == -1) {
			warn("stat: %s", entry->path);
			continue;
		}

		size = (size_t)st.st_size;
		delta = st.st_size - prev_st.st_size;
		delta_abs = (size_t)(delta < 0 ? -delta : delta);
		if (strcmp(entry->basename, "bsd.rd") == 0) {
			if (delta_abs <= threshold_size_ramdisk_b)
				continue;
		} else if (delta_abs <= threshold_size_b) {
			continue;
		}

		str = arena_printf(&s, "Size: %s %s (%c%s)",
		    entry->basename, format_size(size, &s),
		    delta < 0 ? '-' : '+', format_size(delta_abs, &s));
		dst = VECTOR_ALLOC(sizes);
		if (dst == NULL)
			err(1, NULL);
		*dst = str;
	}

	VECTOR_SORT(sizes, size_cmp);
	for (i = 0; i < VECTOR_LENGTH(sizes); i++)
		buffer_printf(r->out, "%s\n", sizes[i]);

out:
	invocation_free(is);
	VECTOR_FREE(sizes);
	return 0;
}

static int
report_stats(struct report_context *r)
{
	SCOPE s = arena_scope(r->arena);
	struct buffer *tags;
	const char *tags_path;
	int error = 0;

	buffer_printf(r->out, "> stats\n");
	buffer_printf(r->out, "Status: %s\n", report_status(r, &s));
	report_stats_duration(r, &s);
	buffer_printf(r->out, "Build: %s\n", r->builddir);

	tags_path = arena_printf(&s, "%s/tags", r->builddir);
	tags = buffer_read(tags_path);
	if (tags != NULL) {
		buffer_printf(r->out, "Tags: ");
		buffer_puts(r->out, buffer_get_ptr(tags), buffer_get_len(tags));
	}
	buffer_free(tags);

	if (r->mode == CONFIG_ROBSD)
		error = report_stats_sizes(r);

	return error;
}

/*
 * Returns non-zero if the corresponding step log contains line(s) without ksh
 * PS4 traces.
 */
static int
is_log_empty(struct report_context *r, const struct step *step)
{
	SCOPE s = arena_scope(r->arena);
	struct buffer *bf;
	const char *buf, *path;
	size_t buflen;
	int empty = 1;

	path = arena_printf(&s, "%s/%s",
	    r->builddir, step_get_field(step, "log")->str);
	bf = buffer_read(path);
	if (bf == NULL)
		return 1;
	buf = buffer_get_ptr(bf);
	buflen = buffer_get_len(bf);
	while (buflen > 0) {
		const char *nx;

		if (buf[0] != '+') {
			empty = 0;
			break;
		}

		nx = memchr(buf, '\n', buflen);
		if (nx == NULL)
			break;
		buflen -= (size_t)(nx - buf) + 1;
		buf = &nx[1];
	}
	buffer_free(bf);

	return empty;
}

static int
report_skip_step(struct report_context *r, const struct step *step)
{
	const char *name;

	if (r->mode == CONFIG_ROBSD_PORTS)
		return ports_report_skip_step(r, step);
	if (r->mode == CONFIG_ROBSD_REGRESS)
		return regress_report_skip_step(r, step);

	name = step_get_field(step, "name")->str;
	if (strcmp(name, "cvs") == 0)
		return 0;
	if (strcmp(name, "checkflist") == 0 && !is_log_empty(r, step))
		return 0;
	return 1;
}

static int
report_step_log(struct report_context *r, const struct step *step,
    struct arena_scope *s)
{
	struct buffer *bf;
	const char *log_path, *name, *str;
	size_t len;
	int rv = 0;

	if (r->mode == CONFIG_ROBSD_PORTS)
		rv = ports_report_step_log(r, step);
	if (r->mode == CONFIG_ROBSD_REGRESS)
		rv = regress_report_step_log(r, step);
	if (rv < 0)
		return 1;
	if (rv > 0)
		return 0;

	name = step_get_field(step, "name")->str;
	if (strcmp(name, "cvs") == 0)
		return report_cvs_log(r) < 0 ? 1 : 0;

	log_path = step_get_log_path(r, step, s);
	if (log_path == NULL)
		return 0;
	bf = buffer_read(log_path);
	if (bf == NULL) {
		warn("%s", log_path);
		return 1;
	}
	str = last_lines(buffer_get_ptr(bf), buffer_get_len(bf), &len, 10);
	buffer_printf(r->out, "\n%.*s", (int)len, str);
	if (len > 0 && str[len - 1] != '\n')
		buffer_putc(r->out, '\n');
	buffer_free(bf);

	return 0;
}

static int
report_steps(struct report_context *r)
{
	size_t i, nsteps;

	nsteps = VECTOR_LENGTH(r->steps);
	for (i = 0; i < nsteps; i++) {
		SCOPE s = arena_scope(r->arena);
		const struct step *step = &r->steps[i];
		const char *duration;

		if (step_get_field(step, "skip")->integer == 1)
			continue;

		if (step_get_field(step, "exit")->integer == 0 &&
		    report_skip_step(r, step))
			continue;

		buffer_printf(r->out, "\n> %s\n",
		    step_get_field(step, "name")->str);

		buffer_printf(r->out, "Exit: %d\n",
		    (int)step_get_field(step, "exit")->integer);

		duration = format_duration_and_delta(
		    step_get_field(step, "duration")->integer,
		    step_get_field(step, "delta")->integer,
		    0, &s);
		buffer_printf(r->out, "Duration: %s\n", duration);

		buffer_printf(r->out, "Log: %s\n",
		    step_get_field(step, "log")->str);

		if (report_step_log(r, step, &s))
			return 1;
	}

	return 0;
}

int
report_generate(struct config *config, const char *builddir,
    struct buffer *out)
{
	ARENA arena[512 * 1024];
	SCOPE s = {0};
	struct report_context r;
	struct step *steps = NULL;
	const char *steps_path;
	int error = 1;

	if (arena_init(arena, ARENA_FATAL)) {
		warn("arena_init");
		goto out;
	}
	s = arena_scope(arena);

	steps_path = arena_printf(&s, "%s/step.csv", builddir);
	steps = steps_parse(steps_path);
	if (steps == NULL)
		goto out;

	r = (struct report_context){
	    .arena		= arena,
	    .builddir		= builddir,
	    .prev_builddir	= previous_builddir(config, builddir, &s),
	    .config		= config,
	    .steps		= steps,
	    .out		= out,
	    .mode		= config_get_mode(config),
	};
	error = report_subject(&r) ||
	    report_comment(&r) ||
	    report_stats(&r) ||
	    report_steps(&r);

out:
	steps_free(steps);
	arena_free(arena);
	return error;
}
