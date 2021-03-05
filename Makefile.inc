SHELLCHECKFLAGS+=	-f gcc
SHELLCHECKFLAGS+=	-s ksh
SHELLCHECKFLAGS+=	-e SC1090			# non-constant source
SHELLCHECKFLAGS+=	-e SC1091			# not following source
SHELLCHECKFLAGS+=	-e SC2012			# find instead of ls
SHELLCHECKFLAGS+=	-e SC2164			# cd failure
SHELLCHECKFLAGS +=	-o add-default-case
SHELLCHECKFLAGS +=	-o avoid-nullary-conditions
SHELLCHECKFLAGS +=	-o quote-safe-variables

lint: _SUBDIRUSE
.if defined(MANLINT)
	mandoc -Tlint -Wstyle ${MANLINT}
.endif
.if defined(SHLINT)
	shellcheck ${SHELLCHECKFLAGS} ${SHLINT}
.endif
.PHONY: lint

.include <bsd.subdir.mk>
