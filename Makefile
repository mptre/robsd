PROG=	 release

SCRIPTS+=	base.sh
SCRIPTS+=	cvs.sh
SCRIPTS+=	diff-revert.sh
SCRIPTS+=	diff.sh
SCRIPTS+=	distrib.sh
SCRIPTS+=	image.sh
SCRIPTS+=	kernel.sh
SCRIPTS+=	release.sh
SCRIPTS+=	start.sh
SCRIPTS+=	xbase.sh
SCRIPTS+=	xrelease.sh

PREFIX=	/usr/local

all:

install:
	mkdir -p ${DESTDIR}${PREFIX}/sbin
	${INSTALL} -m 0755 ${.CURDIR}/${PROG} ${DESTDIR}${PREFIX}/sbin
	mkdir -p ${DESTDIR}${PREFIX}/libexec/${PROG}
.for s in ${SCRIPTS}
	${INSTALL} -m 0644 ${.CURDIR}/$s \
		${DESTDIR}${PREFIX}/libexec/${PROG}/$s
.endfor
