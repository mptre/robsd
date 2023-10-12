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
	/* Number of ASAN poison bytes between allocations. */
	size_t			 poison_size;
	struct {
		unsigned int	fatal:1,
				dying:1;
	} flags;
	int			 refs;
	struct arena_stats	 stats;
};

union address {
	char		*s8;
	uint64_t	 u64;
};

static const size_t maxalign = sizeof(void *);

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

static union address
align_address(const struct arena *a, union address addr)
{
	addr.u64 = (addr.u64 + maxalign - 1) & ~(maxalign - 1);
	if (a->poison_size > 0) {
		if (a->poison_size > INT64_MAX - addr.u64) {
			/* Insufficient space for poison bytes is not fatal. */
		} else {
			addr.u64 += a->poison_size;
		}
	}
	return addr;
}

static void
arena_ref(struct arena *a)
{
	a->refs++;
}

static void
arena_rele(struct arena *a)
{
	if (--a->refs > 0)
		return;
	free(a);
}

static void *
arena_push(struct arena *a, struct arena_frame *frame, size_t size)
{
	void *ptr;
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
	newlen = align_address(a, (union address){.u64 = newlen}).u64;
	/*
	 * Discard alignment if the frame is exhausted, the next allocation will
	 * require a new frame anyway.
	 */
	frame->len = newlen > frame->size ? frame->size : newlen;
	return ptr;
}

static int
arena_frame_alloc(struct arena *a, size_t frame_size)
{
	struct arena_frame *frame;

	frame = malloc(frame_size);
	if (frame == NULL)
		return 0;
	frame->ptr = (char *)frame;
	frame->size = frame_size;
	frame->len = 0;
	frame->next = NULL;
	if (arena_push(a, frame, sizeof(*frame)) == NULL) {
		free(frame);
		errno = ENOMEM;
		return 0;
	}
	frame->next = a->frame;
	a->frame = frame;
	frame_poison(a->frame);

	a->stats.bytes.now += frame_size;
	a->stats.bytes.total += frame_size;
	a->stats.frames.now++;
	a->stats.frames.total++;

	return 1;
}

struct arena *
arena_alloc(unsigned int flags)
{
	struct arena *a;
	long page_size;

	page_size = sysconf(_SC_PAGESIZE);
	if (page_size == -1) {
		if (flags & ARENA_FATAL)
			err(1, "sysconf");
		return NULL;
	}

	a = calloc(1, sizeof(*a));
	if (a == NULL) {
		if (flags & ARENA_FATAL)
			err(1, "%s", __func__);
		return NULL;
	}
	a->frame_size = 16 * (size_t)page_size;
	a->poison_size = POISON_SIZE;
	a->flags.fatal = (flags & ARENA_FATAL) ? 1u : 0;
	arena_ref(a);
	if (!arena_frame_alloc(a, a->frame_size)) {
		arena_free(a);
		if (flags & ARENA_FATAL)
			err(1, "%s", __func__);
		return NULL;
	}

	return a;
}

void
arena_free(struct arena *a)
{
	arena_ref(a);
	arena_scope_leave(&(struct arena_scope){.arena = a});
	/* Signal to any scope(s) still alive that the arena is gone. */
	a->flags.dying = 1;
	arena_rele(a);
}

void
arena_scope_leave(struct arena_scope *s)
{
	struct arena *a = s->arena;

	/* Do nothing if arena_free() already has been called. */
	if (a->flags.dying) {
		arena_rele(a);
		return;
	}

	while (a->frame != NULL && a->frame != s->frame) {
		struct arena_frame *frame = a->frame;

		a->stats.bytes.now -= frame->size;
		a->stats.frames.now--;

		a->frame = frame->next;
		free(frame);
	}
	if (a->frame != NULL) {
		a->frame->len = s->frame_len <= a->frame->len ?
		    s->frame_len : 0;
		frame_poison(a->frame);
	}

	arena_rele(a);
}

struct arena_scope
arena_scope_enter(struct arena *a)
{
	arena_ref(a);
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
		if (a->flags.fatal)
			err(1, "%s", __func__);
		return NULL;
	}
	total_size = size + sizeof(*frame);

	frame_size = a->frame_size;
	while (frame_size < total_size) {
		if (frame_size > INT64_MAX / frame_size) {
			a->stats.overflow |= 4;
			errno = EOVERFLOW;
			if (a->flags.fatal)
				err(1, "%s", __func__);
			return NULL;
		}
		frame_size <<= 1;
	}

	if (!arena_frame_alloc(a, frame_size)) {
		if (a->flags.fatal)
			err(1, "%s", __func__);
		return NULL;
	}

	ptr = arena_push(a, a->frame, size);
	if (ptr == NULL) {
		errno = ENOMEM;
		if (a->flags.fatal)
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
		if (a->flags.fatal)
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

static int
arena_realloc_fast(struct arena_scope *s, char *ptr, size_t old_size,
    size_t new_size)
{
	struct arena_frame frame;
	struct arena *a = s->arena;
	union address old_addr;

	/* Always allow existing allocations to shrink. */
	if (new_size <= old_size) {
		arena_poison(&ptr[new_size], old_size - new_size);
		return 1;
	}

	/* Check if this is the last allocated object. */
	old_addr.s8 = ptr;
	old_addr.u64 += old_size;
	old_addr = align_address(a, old_addr);
	if (old_addr.s8 != &a->frame->ptr[a->frame->len])
		return 0;

	/* Check if the new size still fits within the current frame. */
	frame = *a->frame;
	frame.len = (size_t)(ptr - frame.ptr);
	if (arena_push(a, &frame, new_size) == NULL)
		return 0;

	*a->frame = frame;
	return 1;
}

void *
arena_realloc(struct arena_scope *s, void *ptr, size_t old_size,
    size_t new_size)
{
	struct arena *a = s->arena;
	void *new_ptr;
	union address old_addr;

	old_addr.s8 = ptr;
	if ((old_addr.u64 & (maxalign - 1)) != 0) {
		errno = EFAULT;
		return NULL;
	}

	a->stats.realloc.total++;

	/* Fast path while reallocating last allocated object. */
	if (ptr != NULL && arena_realloc_fast(s, ptr, old_size, new_size)) {
		a->stats.realloc.fast++;
		return ptr;
	}

	new_ptr = arena_malloc(s, new_size);
	if (new_ptr == NULL)
		return NULL;
	if (ptr != NULL)
		memcpy(new_ptr, ptr, old_size);
	a->stats.realloc.spill += old_size;
	return new_ptr;
}

char *
arena_sprintf(struct arena_scope *s, const char *fmt, ...)
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
	rollback = arena_scope_enter(a);
	str = arena_malloc(s, len);
	n = vsnprintf(str, len, fmt, ap);
	if (n < 0 || (size_t)n >= len) {
		arena_scope_leave(&rollback);
		str = NULL;
	} else {
		arena_rele(a);
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
		if (a->flags.fatal)
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
arena_stats(struct arena *a)
{
	return &a->stats;
}

void
arena_poison(void *ptr __attribute__((unused)),
    size_t size __attribute__((unused)))
{
	ASAN_POISON_MEMORY_REGION(ptr, size);
}
