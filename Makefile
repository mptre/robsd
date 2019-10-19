SCRIPTS+=	base.sh
SCRIPTS+=	checkflist.sh
SCRIPTS+=	cvs.sh
SCRIPTS+=	distrib.sh
SCRIPTS+=	env.sh
SCRIPTS+=	image.sh
SCRIPTS+=	kernel.sh
SCRIPTS+=	patch.sh
SCRIPTS+=	release.sh
SCRIPTS+=	revert.sh
SCRIPTS+=	util.sh
SCRIPTS+=	xbase.sh
SCRIPTS+=	xrelease.sh

PREFIX?=	/usr/local
BINDIR?=	${PREFIX}/sbin
LIBEXECDIR?=	${PREFIX}/libexec
MANDIR?=	${PREFIX}/man
INSTALL?=	install
INSTALL_MAN?=	install

SHELLCHECKFLAGS+=	-f gcc
SHELLCHECKFLAGS+=	-e SC1090	# non-constant source
SHELLCHECKFLAGS+=	-e SC1091	# constant source
SHELLCHECKFLAGS+=	-e SC2012	# find instead of ls
SHELLCHECKFLAGS+=	-e SC2148	# missing shebang
SHELLCHECKFLAGS+=	-e SC2164	# cd failure

all:

install:
	mkdir -p ${DESTDIR}${BINDIR}
	${INSTALL} -m 0755 ${.CURDIR}/robsd ${DESTDIR}${BINDIR}
	${INSTALL} -m 0755 ${.CURDIR}/robsd-clean ${DESTDIR}${BINDIR}
	mkdir -p ${DESTDIR}${LIBEXECDIR}/robsd
.for s in ${SCRIPTS}
	${INSTALL} -m 0644 ${.CURDIR}/$s ${DESTDIR}${LIBEXECDIR}/robsd/$s
.endfor
	@mkdir -p ${DESTDIR}${MANDIR}/man8
	${INSTALL_MAN} ${.CURDIR}/robsd.8 ${DESTDIR}${MANDIR}/man8
	${INSTALL_MAN} ${.CURDIR}/robsd-clean.8 ${DESTDIR}${MANDIR}/man8
	${INSTALL_MAN} ${.CURDIR}/robsdrc.5 ${DESTDIR}${MANDIR}/man5
.PHONY: install

lint:
	mandoc -Tlint -Wstyle \
		${.CURDIR}/robsd.8 \
		${.CURDIR}/robsd-clean.8 \
		${.CURDIR}/robsdrc.5
	shellcheck ${SHELLCHECKFLAGS} \
		${SCRIPTS:C/^/${.CURDIR}\//} \
		${.CURDIR}/robsd \
		${.CURDIR}/robsd-clean
.PHONY: lint

test:
	${MAKE} -C ${.CURDIR}/tests \
		"EXECDIR=${.CURDIR}" \
		"TESTFLAGS=${TESTFLAGS}"
.PHONY: test
