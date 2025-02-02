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

#ifndef LIBKS_COMPILER_H
#define LIBKS_COMPILER_H

#if !defined(__has_attribute)
#  define __has_attribute(x) 0
#endif

#define UNUSED(x)	_##x __attribute__((unused))

#ifndef NDEBUG
#define NDEBUG_UNUSED(x) x
#else
#define NDEBUG_UNUSED(x) UNUSED(x)
#endif

#define likely(x)	__builtin_expect((x), 1)
#define unlikely(x)	__builtin_expect((x), 0)

#if __has_attribute(fallthrough)
#  define FALLTHROUGH	__attribute__((fallthrough))
#else
#  define FALLTHROUGH	do {} while (0) /* FALLTHROUGH */
#endif

#define UNSAFE_CAST(type, ptr) __extension__ ({			\
	union {							\
		__typeof__(ptr) src;				\
		type dst;					\
	} _u = {.src = (ptr)};					\
	_u.dst;							\
})

#endif /* !LIBKS_COMPILER_H */
