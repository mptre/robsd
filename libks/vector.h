/*
 * Copyright (c) 2022 Anton Lindqvist <anton@basename.se>
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

#ifndef LIBKS_VECTOR_H
#define LIBKS_VECTOR_H

#include <limits.h>	/* ULONG_MAX */
#include <stddef.h>	/* size_t */

enum vector_type {
	VECTOR_DEFAULT,
	VECTOR_ARENA,
};

struct vector_public {
	size_t			len;
	size_t			stride;
	enum vector_type	type;
};

struct vector_callbacks {
	void	*(*calloc)(size_t, size_t, void *);
	void	*(*realloc)(void *, size_t, size_t, void *);
	void	 (*free)(void *, size_t, void *);
	void	*arg;
};

#define VECTOR(type) type *

#define VECTOR_INIT(vc) vector_init((void **)&(vc), sizeof(*(vc)))
int	vector_init(void **, size_t);
int	vector_init_impl(enum vector_type, void **, size_t,
    const struct vector_callbacks *);

#define VECTOR_FREE(vc) vector_free((void **)&(vc))
void	vector_free(void **);

#define VECTOR_RESERVE(vc, n) vector_reserve((void **)&(vc), (n))
int	vector_reserve(void **, size_t);

#define VECTOR_ALLOC(vc) __extension__ ({				\
	size_t _i = vector_alloc((void **)&(vc), 0);			\
	_i == ULONG_MAX ? NULL : (vc) + _i;				\
})
#define VECTOR_CALLOC(vc) __extension__ ({				\
	size_t _i = vector_alloc((void **)&(vc), 1);			\
	_i == ULONG_MAX ? NULL : (vc) + _i;				\
})
size_t	vector_alloc(void **, int);

#define VECTOR_POP(vc) __extension__ ({					\
	size_t _i = vector_pop((void *)(vc));				\
	_i == ULONG_MAX ? NULL : (vc) + _i;				\
})
size_t	vector_pop(void *);

#define VECTOR_CLEAR(vc) vector_clear((void *)(vc))
void	vector_clear(void *);

#define VECTOR_SORT(vc, c) __extension__ ({				\
	int (*_c)(const typeof(*(vc)) *, const typeof(*(vc)) *) = &(c);	\
	vector_sort((void *)(vc), (int (*)(const void *, const void *))_c);\
})
void	vector_sort(void *, int (*)(const void *, const void *));

#define VECTOR_FIRST(vc) __extension__ ({				\
	size_t _i = vector_first((void *)(vc));				\
	_i == ULONG_MAX ? NULL : (vc) + _i;				\
})
size_t	vector_first(void *);

#define VECTOR_LAST(vc) __extension__ ({				\
	size_t _i = vector_last((void *)(vc));				\
	_i == ULONG_MAX ? NULL : (vc) + _i;				\
})
size_t	vector_last(void *);

#define VECTOR_LENGTH(vc) vector_length((const void *)(vc))
static inline size_t
vector_length(const void *vc)
{
	const struct vector_public *vp = vc;
	return vp[-1].len;
}

#define VECTOR_STRIDE(vc) vector_stride((const void *)(vc))
static inline size_t
vector_stride(const void *vc)
{
	const struct vector_public *vp = vc;
	return vp[-1].stride;
}

static inline enum vector_type
vector_type(const void *vc)
{
	const struct vector_public *vp = vc;
	return vp[-1].type;
}

#define VECTOR_EMPTY(vc) (VECTOR_LENGTH(vc) == 0)

#endif /* !LIBKS_VECTOR_H */
