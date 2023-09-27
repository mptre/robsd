/*
 * Copyright (c) 2023 Anton Lindqvist <anton@basename.se>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#include "libks/arena.h"

#include <err.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#if defined(__has_feature)
#  if  __has_feature(address_sanitizer)
#    define HAVE_ASAN 1	/* clang */
#  endif
#elif defined(__SANITIZE_ADDRESS__)
#  define HAVE_ASAN 1	/ * gcc */
#endif
#if defined(HAVE_ASAN)
#  include <sanitizer/asan_interface.h>
#  define POISON_SIZE 8
#else
#  define ASAN_POISON_MEMORY_REGION(...) (void)0
#  define ASAN_UNPOISON_MEMORY_REGION(...) (void)0
#  define POISON_SIZE 0
#endif

struct arena_frame {
	char			*ptr;
	size_t			 size;
	size_t			 len;
	struct arena_frame	*next;
};

struct arena {
	struct arena_frame	*frame;
	/* Initial heap frame size, multiple of page size. */
	size_t			 frame_size;
	/*
	 * Number of bytes in stack frame occupied by the arena and stack frame
	 * itself.
	 */
	size_t			 stack_frame_size;
	/* Number of ASAN poison bytes between allocations. */
	size_t			 poison_size;
	unsigned long		 flags;
	struct arena_stats	 stats;
};

static void
frame_poison(struct arena_frame *frame __attribute__((unused)))
{
#if 0
	// XXX
	fprintf(stderr, "[P] %10zu [%p, %p)\n",
	    frame->size - frame->len,
	    (void *)&frame->ptr[frame->len],
	    (void *)&frame->ptr[frame->size]);
#endif
	ASAN_POISON_MEMORY_REGION(&frame->ptr[frame->len],
	    frame->size - frame->len);
}

static void
frame_unpoison(struct arena_frame *frame __attribute__((unused)),
    size_t size __attribute__((unused)))
{
#if 0
	// XXX
	fprintf(stderr, "[U] %10zu [%p, %p)\n",
	    size,
	    (void *)&frame->ptr[frame->len],
	    (void *)&frame->ptr[frame->len + size]);
#endif
	ASAN_UNPOISON_MEMORY_REGION(&frame->ptr[frame->len], size);
}

static int
is_fatal(const struct arena *a)
{
	return !!(a->flags & ARENA_FATAL);
}

static int
is_stack_frame(const struct arena *a)
{
	return (const struct arena_frame *)&a[1] == a->frame;
}

static void *
arena_push(struct arena *a, struct arena_frame *frame, size_t size)
{
	void *ptr;
	size_t maxalign = sizeof(void *);
	uint64_t newlen;

	if (size > INT64_MAX - frame->len) {
		a->stats.overflow |= 1;
		errno = EOVERFLOW;
		return NULL;
	}
	newlen = frame->len + size;
	if (newlen > frame->size) {
		errno = ENOMEM;
		return NULL;
	}

	frame_unpoison(frame, size);
	ptr = &frame->ptr[frame->len];
	newlen = (newlen + maxalign - 1) & ~(maxalign - 1);
	if (a->poison_size > 0) {
		if (a->poison_size > INT64_MAX - newlen) {
			/* Insufficient space for poison bytes is not fatal. */
		} else {
			newlen += a->poison_size;
		}
	}
	frame->len = newlen > frame->size ? frame->size : newlen;
	return ptr;
}

int
arena_init_impl(ARENA *aa, size_t stack_size, unsigned int flags)
{
	struct arena *a = (struct arena *)aa;
	struct arena_frame *frame = (struct arena_frame *)&a[1];
	long page_size;

	if (stack_size < sizeof(*a) + sizeof(*frame)) {
		errno = EINVAL;
		return 1;
	}

	page_size = sysconf(_SC_PAGESIZE);
	if (page_size == -1)
		return 1;

	/* Place the first frame on the stack and account for it. */
	memset(a, 0, sizeof(*a));
	a->frame = frame;
	frame->ptr = aa;
	frame->size = stack_size;
	frame->len = 0;
	frame->next = NULL;
	if (arena_push(a, a->frame, sizeof(*frame)) == NULL)
		return 1;

	/* Place the arena on the stack and account for it. */
	if (arena_push(a, a->frame, sizeof(*a)) == NULL)
		return 1;
	a->frame_size = 16 * (size_t)page_size;
	a->stack_frame_size = a->frame->len;
	a->poison_size = POISON_SIZE;
	a->flags = flags;

	frame_poison(a->frame);

	return 0;
}

void
arena_free(ARENA *aa)
{
	struct arena *a = (struct arena *)aa;

	arena_leave(&(struct arena_scope){
	    .arena	= a,
	    .frame	= (struct arena_frame *)&a[1],
	    .frame_len	= a->stack_frame_size,
	});
	frame_unpoison(a->frame, a->frame->size - a->frame->len);
	/* Signal to any scope(s) still alive that the arena is gone. */
	a->frame = NULL;
}

void
arena_leave(struct arena_scope *s)
{
	struct arena *a = s->arena;

	if (s->arena == NULL || a->frame == NULL)
		return;

	while (a->frame != s->frame && !is_stack_frame(a)) {
		struct arena_frame *frame = a->frame;

		a->stats.heap.now -= frame->size;
		a->stats.heap.total -= frame->size;
		a->stats.frames.now--;

		a->frame = frame->next;
		free(frame);
	}
	a->frame->len = s->frame_len <= a->frame->len ? s->frame_len : 0;
	frame_poison(a->frame);
}

struct arena_scope
arena_scope(ARENA *aa)
{
	struct arena *a = (struct arena *)aa;

	return (struct arena_scope){
	    .arena	= a,
	    .frame	= a->frame,
	    .frame_len	= a->frame->len,
	};
}

void *
arena_malloc(struct arena_scope *s, size_t size)
{
	struct arena *a = s->arena;
	struct arena_frame *frame;
	void *ptr;
	uint64_t frame_size, total_size;

	ptr = arena_push(a, a->frame, size);
	if (ptr != NULL)
		return ptr;

	if (sizeof(*frame) > INT64_MAX - size) {
		a->stats.overflow |= 2;
		errno = EOVERFLOW;
		if (is_fatal(a))
			err(1, "%s", __func__);
		return NULL;
	}
	total_size = size + sizeof(*frame);

	frame_size = a->frame_size;
	while (frame_size < total_size) {
		if (frame_size > INT64_MAX / frame_size) {
			a->stats.overflow |= 4;
			errno = EOVERFLOW;
			if (is_fatal(a))
				err(1, "%s", __func__);
			return NULL;
		}
		frame_size <<= 1;
	}

	frame = malloc(frame_size);
	if (frame == NULL) {
		if (is_fatal(a))
			err(1, "%s", __func__);
		return NULL;
	}
	frame->ptr = (char *)frame;
	frame->size = frame_size;
	frame->len = 0;
	frame->next = NULL;
	if (arena_push(a, frame, sizeof(*frame)) == NULL) {
		free(frame);
		errno = ENOMEM;
		if (is_fatal(a))
			err(1, "%s", __func__);
		return NULL;
	}
	frame->next = a->frame;
	a->frame = frame;
	frame_poison(a->frame);

	a->stats.heap.now += frame_size;
	a->stats.heap.total += frame_size;
	a->stats.frames.now++;
	a->stats.frames.total++;

	ptr = arena_push(a, a->frame, size);
	if (ptr == NULL) {
		errno = ENOMEM;
		if (is_fatal(a))
			err(1, "%s", __func__);
		return NULL;
	}
	return ptr;
}

void *
arena_calloc(struct arena_scope *s, size_t nmemb, size_t size)
{
	struct arena *a = s->arena;
	void *ptr;
	uint64_t total_size;

	if (nmemb > INT64_MAX / size) {
		errno = EOVERFLOW;
		if (is_fatal(a))
			err(1, "%s", __func__);
		return NULL;
	}
	total_size = nmemb * size;

	ptr = arena_malloc(s, total_size);
	if (ptr == NULL)
		return NULL;
	memset(ptr, 0, total_size);
	return ptr;
}

char *
arena_printf(struct arena_scope *s, const char *fmt, ...)
{
	struct arena_scope rollback;
	va_list ap, cp;
	struct arena *a = s->arena;
	char *str = NULL;
	size_t len;
	int n;

	va_start(ap, fmt);

	va_copy(cp, ap);
	n = vsnprintf(NULL, 0, fmt, cp);
	va_end(cp);
	if (n < 0)
		goto out;

	len = (size_t)n + 1;
	rollback = arena_scope((ARENA *)a);
	str = arena_malloc(s, len);
	n = vsnprintf(str, len, fmt, ap);
	if (n < 0 || (size_t)n >= len) {
		arena_leave(&rollback);
		str = NULL;
	}

out:
	va_end(ap);
	return str;
}

char *
arena_strdup(struct arena_scope *s, const char *src)
{
	return arena_strndup(s, src, strlen(src));
}

char *
arena_strndup(struct arena_scope *s, const char *src, size_t len)
{
	struct arena *a = s->arena;
	char *dst;
	uint64_t total_size;

	if (len > INT64_MAX - 1) {
		errno = EOVERFLOW;
		if (is_fatal(a))
			err(1, "%s", __func__);
		return NULL;
	}
	total_size = len + 1;

	dst = arena_malloc(s, total_size);
	if (dst == NULL)
		return NULL;
	memcpy(dst, src, total_size - 1);
	dst[total_size - 1] = '\0';
	return dst;
}

struct arena_stats *
arena_stats(ARENA *aa)
{
	struct arena *a = (struct arena *)aa;

	return &a->stats;
}
