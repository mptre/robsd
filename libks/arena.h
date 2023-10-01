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

#include <stddef.h>	/* size_t */
#include <stdint.h>

#define ARENA_FATAL		0x00000001u

struct arena {
	uint8_t	u8;
};

typedef char ARENA;

#define ARENA_SCOPE __attribute__((cleanup(arena_leave))) struct arena_scope

struct arena_scope {
	struct arena_impl	*arena;
	struct arena_frame	*frame;
	size_t			 frame_len;
};

struct arena_stats {
	struct {
		/* Effective amount of allocated bytes. */
		unsigned long	now;
		/* Total amount of allocated bytes. */
		unsigned long	total;
	} heap;

	struct {
		/* Effective amount of allocated frames. */
		unsigned long	now;
		/* Total amount of allocated frames. */
		unsigned long	total;
	} frames;

	/* Overflow scenario(s) hit during frame size calculation. */
	unsigned long	overflow;
};

#define arena_init(a, flags) arena_init_impl((a), sizeof(a), (flags))
int	arena_init_impl(struct arena *, size_t, unsigned int);

void	arena_free(struct arena *);

void	arena_leave(struct arena_scope *);

struct arena_scope  arena_scope(struct arena *);

void	*arena_malloc(struct arena_scope *, size_t)
	__attribute__((malloc, alloc_size(2)));
void	*arena_calloc(struct arena_scope *, size_t, size_t)
	__attribute__((malloc, alloc_size(2, 3)));

char	*arena_sprintf(struct arena_scope *, const char *, ...)
	__attribute__((__format__(printf, 2, 3)));

char	*arena_strdup(struct arena_scope *, const char *);
char	*arena_strndup(struct arena_scope *, const char *, size_t);

struct arena_stats	*arena_stats(struct arena *);
