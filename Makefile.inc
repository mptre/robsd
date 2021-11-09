SHELLCHECKFLAGS+=	-f gcc
SHELLCHECKFLAGS+=	-s ksh
SHELLCHECKFLAGS+=	-e SC1090			# non-constant source
SHELLCHECKFLAGS+=	-e SC1091			# not following source
SHELLCHECKFLAGS+=	-e SC2012			# find instead of ls
SHELLCHECKFLAGS+=	-e SC2164			# cd failure
SHELLCHECKFLAGS+=	-o add-default-case
SHELLCHECKFLAGS+=	-o avoid-nullary-conditions
SHELLCHECKFLAGS+=	-o quote-safe-variables

# Get rid of annoying white space.
SHELLCHECKFLAGS!=	echo ${SHELLCHECKFLAGS}

NCPU!!=	sysctl -n hw.ncpuonline

lint: _SUBDIRUSE
.if defined(KNFMT)
	cd ${.CURDIR} && knfmt -d ${KNFMT}
.endif
.if defined(MANLINT)
	cd ${.CURDIR} && mandoc -Tlint -Wstyle ${MANLINT}
.endif
.if defined(SHLINT)
	cd ${.CURDIR} && echo ${SHLINT} | \
	xargs -n1 -P${NCPU} shellcheck ${SHELLCHECKFLAGS}
.endif
.PHONY: lint

.include <bsd.subdir.mk>
