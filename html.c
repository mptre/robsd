#include "html.h"

#include "config.h"

#include <assert.h>
#include <err.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

#include "libks/buffer.h"

#include "alloc.h"

struct html {
	struct buffer	*bf;
	unsigned int	 depth;
};

static void	html_indent(struct html *);

struct html_attribute	html_attr_last;

struct html *
html_alloc(void)
{
	struct html *html;

	html = ecalloc(1, sizeof(*html));
	html->bf = buffer_alloc(1 << 10);
	if (html->bf == NULL)
		err(1, NULL);
	return html;
}

void
html_free(struct html *html)
{
	if (html == NULL)
		return;
	buffer_free(html->bf);
	free(html);
}

int
html_write(const struct html *html, const char *path)
{
	struct buffer *bf = html->bf;
	FILE *fh;
	size_t n;
	int error = 0;

	buffer_printf(html->bf, "</body>\n");
	buffer_printf(html->bf, "</html>\n");

	fh = fopen(path, "we");
	if (fh == NULL) {
		warn("fopen: %s", path);
		return 1;
	}
	n = fwrite(buffer_get_ptr(bf), buffer_get_len(bf), 1, fh);
	if (n < 1) {
		warn("fwrite: %s", path);
		error = 1;
	}
	fclose(fh);
	return error;
}

int
html_head_enter(struct html *html)
{
	const char head[] = ""
	    "<!doctype html>\n"
	    "<html lang=\"en\">\n"
	    "<head>\n"
	    "  <meta charset=\"utf-8\">\n"
	    "  <style>\n"
	    "    table { border-spacing: 0; }\n"
	    "    thead { background: #fff; position: sticky; top: 0; }\n"
	    "    td, th { border: #fff 1px solid; }\n"
	    "    th { font-weight: normal; text-align: left; }\n"
	    "    td.PASS { background: #80ff80; }\n"
	    "    td.FAIL { background: #ff8080; }\n"
	    "    td.XFAIL { background: #80ffc0; }\n"
	    "    td.XPASS { background: #ff80c0; }\n"
	    "    td.SKIP { background: #8080ff; }\n"
	    "    a.status { color: #000; }\n"
	    "  </style>\n";

	html_indent(html);
	html->depth++;
	buffer_printf(html->bf, head);
	return 1;
}

int
html_head_leave(struct html *html)
{
	const char head[] = ""
	    "</head>\n"
	    "<body>\n";

	html->depth--;
	html_indent(html);
	buffer_printf(html->bf, head);
	return 0;
}

int
html_node_enter(struct html *html, const char *type, ...)
{
	va_list ap;

	html_indent(html);
	html->depth++;

	buffer_printf(html->bf, "<%s", type);

	va_start(ap, type);
	for (;;) {
		const struct html_attribute *attr;

		attr = va_arg(ap, const struct html_attribute *);
		if (attr == &html_attr_last)
			break;
		buffer_printf(html->bf, " %s=\"%s\"", attr->key, attr->val);
	}
	va_end(ap);

	buffer_printf(html->bf, ">\n");

	return 1;
}

int
html_node_leave(struct html *html, const char *type)
{
	assert(html->depth > 0);
	html->depth--;
	html_indent(html);
	buffer_printf(html->bf, "</%s>\n", type);
	return 0;
}

void
html_text(struct html *html, const char *str)
{
	html_indent(html);
	buffer_printf(html->bf, "%s\n", str);
}

static void
html_indent(struct html *html)
{
	unsigned int i;

	for (i = 0; i < html->depth; i++)
		buffer_printf(html->bf, "  ");
}
