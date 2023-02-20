#include "lexer.h"

#include "config.h"

#include <err.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

#include "alloc.h"
#include "cdefs.h"
#include "token.h"
#include "util.h"

static const char	*lexer_serialize(const struct lexer *,
    const struct token *);

struct lexer {
	TAILQ_HEAD(token_list, token)	 lx_tokens;
	struct token			*lx_tk;

	struct lexer_arg		 lx_arg;
	FILE				*lx_fh;
	int				 lx_lno;
	int				 lx_err;
};

struct lexer *
lexer_alloc(const struct lexer_arg *arg)
{
	FILE *fh;
	struct lexer *lx;
	int error = 0;

	fh = fopen(arg->path, "re");
	if (fh == NULL) {
		warn("open: %s", arg->path);
		return NULL;
	}
	lx = ecalloc(1, sizeof(*lx));
	lx->lx_arg = *arg;
	lx->lx_fh = fh;
	lx->lx_lno = 1;
	lx->lx_tk = NULL;
	TAILQ_INIT(&lx->lx_tokens);

	for (;;) {
		struct token *tk;

		tk = arg->callbacks.read(lx, arg->callbacks.arg);
		if (tk == NULL) {
			error = 1;
			goto out;
		}
		TAILQ_INSERT_TAIL(&lx->lx_tokens, tk, tk_entry);
		if (tk->tk_type == LEXER_EOF)
			break;
	}

out:
	fclose(lx->lx_fh);
	lx->lx_fh = NULL;
	if (error) {
		lexer_free(lx);
		return NULL;
	}
	return lx;
}

void
lexer_free(struct lexer *lx)
{
	struct token *tk;

	if (lx == NULL)
		return;

	while ((tk = TAILQ_FIRST(&lx->lx_tokens)) != NULL) {
		TAILQ_REMOVE(&lx->lx_tokens, tk, tk_entry);
		token_free(tk);
	}
	if (lx->lx_fh != NULL)
		fclose(lx->lx_fh);
	free(lx);
}

struct token *
lexer_emit(struct lexer *UNUSED(lx), const struct lexer_state *s, int type)
{
	struct token *tk;

	tk = token_alloc(type);
	tk->tk_lno = s->lno;
	return tk;
}

int
lexer_getc(struct lexer *lx, char *ch)
{
	int rv;

	rv = fgetc(lx->lx_fh);
	if (rv == EOF) {
		if (ferror(lx->lx_fh)) {
			lexer_warn(lx, lx->lx_lno, "fgetc");
			return 1;
		}
		*ch = 0;
		return 0;
	}
	if (rv == '\n')
		lx->lx_lno++;
	*ch = rv;
	return 0;
}

void
lexer_ungetc(struct lexer *lx, char ch)
{
	if (ch == '\n' && lx->lx_lno > 1)
		lx->lx_lno--;
	(void)ungetc(ch, lx->lx_fh);
}

int
lexer_next(struct lexer *lx, struct token **tk)
{
	if (lx->lx_tk == NULL)
		lx->lx_tk = TAILQ_FIRST(&lx->lx_tokens);
	else if (lx->lx_tk->tk_type != LEXER_EOF)
		lx->lx_tk = TAILQ_NEXT(lx->lx_tk, tk_entry);
	if (lx->lx_tk == NULL)
		return 0;
	*tk = lx->lx_tk;
	return 1;
}

int
lexer_expect(struct lexer *lx, int exp, struct token **tk)
{
	int act;

	if (!lexer_next(lx, tk))
		return 0;
	act = (*tk)->tk_type;
	if (exp != act) {
		lexer_warnx(lx, (*tk)->tk_lno, "want %s, got %s",
		    lexer_serialize(lx, &(struct token){.tk_type = exp}),
		    lexer_serialize(lx, *tk));
		return 0;
	}
	return 1;
}

int
lexer_peek(struct lexer *lx, int type)
{
	struct token *tk;
	int peek;

	if (!lexer_next(lx, &tk))
		return 0;
	peek = tk->tk_type == type;
	lx->lx_tk = TAILQ_PREV(tk, token_list, tk_entry);
	return peek;
}

int
lexer_if(struct lexer *lx, int type, struct token **tk)
{
	if (!lexer_next(lx, tk))
		return 0;
	if ((*tk)->tk_type != type) {
		lx->lx_tk = TAILQ_PREV(*tk, token_list, tk_entry);
		return 0;
	}
	return 1;
}

int
lexer_get_error(const struct lexer *lx)
{
	return lx->lx_err;
}

struct lexer_state
lexer_get_state(const struct lexer *lx)
{
	return (struct lexer_state){.lno = lx->lx_lno};
}

void
lexer_warn(struct lexer *lx, int lno, const char *fmt, ...)
{
	va_list ap;

	lx->lx_err++;

	va_start(ap, fmt);
	logv(warn, lx->lx_arg.path, lno, fmt, ap);
	va_end(ap);
}

void
lexer_warnx(struct lexer *lx, int lno, const char *fmt, ...)
{
	va_list ap;

	lx->lx_err++;

	va_start(ap, fmt);
	logv(warnx, lx->lx_arg.path, lno, fmt, ap);
	va_end(ap);
}

static const char *
lexer_serialize(const struct lexer *lx, const struct token *tk)
{
	if (tk->tk_type == LEXER_EOF)
		return "EOF";
	return lx->lx_arg.callbacks.serialize(tk);
}
