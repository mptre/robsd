VERSION=	6.0.0

PROG_robsd-exec=	robsd-exec
SRCS_robsd-exec=	robsd-exec.c
OBJS_robsd-exec=	${SRCS_robsd-exec:.c=.o}
DEPS_robsd-exec=	${SRCS_robsd-exec:.c=.d}

PROG_robsd-stat=	robsd-stat
SRCS_robsd-stat=	robsd-stat.c
OBJS_robsd-stat=	${SRCS_robsd-stat:.c=.o}
DEPS_robsd-stat=	${SRCS_robsd-stat:.c=.d}

CFLAGS+=	-Wall -Wextra -MD -MP

KNFMT+=	robsd-exec.c
KNFMT+=	robsd-stat.c

SCRIPTS+=	robsd-base.sh
SCRIPTS+=	robsd-checkflist.sh
SCRIPTS+=	robsd-cvs.sh
SCRIPTS+=	robsd-distrib.sh
SCRIPTS+=	robsd-env.sh
SCRIPTS+=	robsd-hash.sh
SCRIPTS+=	robsd-image.sh
SCRIPTS+=	robsd-kernel.sh
SCRIPTS+=	robsd-patch.sh
SCRIPTS+=	robsd-ports-distrib.sh
SCRIPTS+=	robsd-ports-dpb.sh
SCRIPTS+=	robsd-ports-proot.sh
SCRIPTS+=	robsd-reboot.sh
SCRIPTS+=	robsd-regress-exec.sh
SCRIPTS+=	robsd-release.sh
SCRIPTS+=	robsd-revert.sh
SCRIPTS+=	robsd-xbase.sh
SCRIPTS+=	robsd-xrelease.sh
SCRIPTS+=	util-ports.sh
SCRIPTS+=	util-regress.sh
SCRIPTS+=	util.sh

DISTFILES+=	CHANGELOG.md
DISTFILES+=	LICENSE
DISTFILES+=	Makefile
DISTFILES+=	Makefile.inc
DISTFILES+=	README.md
DISTFILES+=	robsd
DISTFILES+=	robsd-base.sh
DISTFILES+=	robsd-checkflist.sh
DISTFILES+=	robsd-clean
DISTFILES+=	robsd-clean.8
DISTFILES+=	robsd-cvs.sh
DISTFILES+=	robsd-distrib.sh
DISTFILES+=	robsd-env.sh
DISTFILES+=	robsd-exec.c
DISTFILES+=	robsd-hash.sh
DISTFILES+=	robsd-image.sh
DISTFILES+=	robsd-kernel.sh
DISTFILES+=	robsd-kill
DISTFILES+=	robsd-kill.8
DISTFILES+=	robsd-patch.sh
DISTFILES+=	robsd-ports
DISTFILES+=	robsd-ports-distrib.sh
DISTFILES+=	robsd-ports-dpb.sh
DISTFILES+=	robsd-ports-proot.sh
DISTFILES+=	robsd-ports.8
DISTFILES+=	robsd-reboot.sh
DISTFILES+=	robsd-regress
DISTFILES+=	robsd-regress-exec.sh
DISTFILES+=	robsd-regress.8
DISTFILES+=	robsd-release.sh
DISTFILES+=	robsd-rescue
DISTFILES+=	robsd-rescue.8
DISTFILES+=	robsd-revert.sh
DISTFILES+=	robsd-stat.8
DISTFILES+=	robsd-stat.c
DISTFILES+=	robsd-xbase.sh
DISTFILES+=	robsd-xrelease.sh
DISTFILES+=	robsd.8
DISTFILES+=	robsd.conf.5
DISTFILES+=	tests/Makefile
DISTFILES+=	tests/cleandir.sh
DISTFILES+=	tests/config-load.sh
DISTFILES+=	tests/cvs-log.sh
DISTFILES+=	tests/diff-apply.sh
DISTFILES+=	tests/diff-clean.sh
DISTFILES+=	tests/diff-copy.sh
DISTFILES+=	tests/diff-list.sh
DISTFILES+=	tests/diff-root.sh
DISTFILES+=	tests/duration-total.sh
DISTFILES+=	tests/format-duration.sh
DISTFILES+=	tests/lock-acquire.sh
DISTFILES+=	tests/log-id.sh
DISTFILES+=	tests/ports-report-log.sh
DISTFILES+=	tests/ports-report-skip.sh
DISTFILES+=	tests/prev-release.sh
DISTFILES+=	tests/purge.sh
DISTFILES+=	tests/regress-config-load.sh
DISTFILES+=	tests/regress-failed.sh
DISTFILES+=	tests/regress-report-log.sh
DISTFILES+=	tests/report-duration.sh
DISTFILES+=	tests/report-size.sh
DISTFILES+=	tests/report-skip.sh
DISTFILES+=	tests/report.sh
DISTFILES+=	tests/robsd-ports.sh
DISTFILES+=	tests/robsd-regress.sh
DISTFILES+=	tests/robsd-rescue.sh
DISTFILES+=	tests/robsd.sh
DISTFILES+=	tests/step-end.sh
DISTFILES+=	tests/step-eval.sh
DISTFILES+=	tests/step-id.sh
DISTFILES+=	tests/step-next.sh
DISTFILES+=	tests/step-value.sh
DISTFILES+=	tests/t.sh
DISTFILES+=	tests/util.sh
DISTFILES+=	util-ports.sh
DISTFILES+=	util-regress.sh
DISTFILES+=	util.sh

PREFIX=		/usr/local
BINDIR=		${PREFIX}/sbin
LIBEXECDIR=	${PREFIX}/libexec
MANDIR=		${PREFIX}/man
INSTALL?=	install
INSTALL_MAN?=	${INSTALL}

MANLINT+=	robsd-clean.8
MANLINT+=	robsd-ports.8
MANLINT+=	robsd-regress.8
MANLINT+=	robsd-rescue.8
MANLINT+=	robsd-stat.8
MANLINT+=	robsd.8
MANLINT+=	robsd.conf.5

SHLINT+=	${SCRIPTS}
SHLINT+=	robsd
SHLINT+=	robsd-clean
SHLINT+=	robsd-kill
SHLINT+=	robsd-ports
SHLINT+=	robsd-regress
SHLINT+=	robsd-rescue

SUBDIR+=	tests

all: ${PROG_robsd-exec} ${PROG_robsd-stat}

${PROG_robsd-exec}: ${OBJS_robsd-exec}
	${CC} ${DEBUG} -o ${PROG_robsd-exec} ${OBJS_robsd-exec} ${LDFLAGS}

${PROG_robsd-stat}: ${OBJS_robsd-stat}
	${CC} ${DEBUG} -o ${PROG_robsd-stat} ${OBJS_robsd-stat} ${LDFLAGS}

clean:
	rm -f \
		${DEPS_robsd-exec} ${OBJS_robsd-exec} ${PROG_robsd-exec} \
		${DEPS_robsd-stat} ${OBJS_robsd-stat} ${PROG_robsd-stat}
.PHONY: clean

dist:
	set -e; \
	d=robsd-${VERSION}; \
	mkdir $$d; \
	for f in ${DISTFILES}; do \
		mkdir -p $$d/`dirname $$f`; \
		cp -p ${.CURDIR}/$$f $$d/$$f; \
	done; \
	find $$d -type d -exec touch -r ${.CURDIR}/Makefile {} \;; \
	tar czvf ${.CURDIR}/$$d.tar.gz $$d; \
	(cd ${.CURDIR}; sha256 $$d.tar.gz >$$d.sha256); \
	rm -r $$d
.PHONY: dist

install: all
	mkdir -p ${DESTDIR}${BINDIR}
	${INSTALL} -m 0555 ${.CURDIR}/robsd ${DESTDIR}${BINDIR}
	${INSTALL} -m 0555 ${.CURDIR}/robsd-clean ${DESTDIR}${BINDIR}
	${INSTALL} -m 0555 ${.CURDIR}/robsd-kill ${DESTDIR}${BINDIR}
	${INSTALL} -m 0555 ${.CURDIR}/robsd-rescue ${DESTDIR}${BINDIR}
	mkdir -p ${DESTDIR}${LIBEXECDIR}/robsd
.for s in ${SCRIPTS}
	${INSTALL} -m 0444 ${.CURDIR}/$s ${DESTDIR}${LIBEXECDIR}/robsd/$s
.endfor
	@mkdir -p ${DESTDIR}${MANDIR}/man5
	${INSTALL_MAN} ${.CURDIR}/robsd.conf.5 ${DESTDIR}${MANDIR}/man5
	@mkdir -p ${DESTDIR}${MANDIR}/man8
	${INSTALL_MAN} ${.CURDIR}/robsd.8 ${DESTDIR}${MANDIR}/man8
	${INSTALL_MAN} ${.CURDIR}/robsd-clean.8 ${DESTDIR}${MANDIR}/man8
	${INSTALL_MAN} ${.CURDIR}/robsd-kill.8 ${DESTDIR}${MANDIR}/man8
	${INSTALL_MAN} ${.CURDIR}/robsd-rescue.8 ${DESTDIR}${MANDIR}/man8
# robsd-exec
	${INSTALL} -m 0555 ${PROG_robsd-exec} ${DESTDIR}${LIBEXECDIR}/robsd
# robsd-ports
	${INSTALL} -m 0555 ${.CURDIR}/robsd-ports ${DESTDIR}${BINDIR}
	ln -f ${DESTDIR}${BINDIR}/robsd-clean ${DESTDIR}${BINDIR}/robsd-ports-clean
	ln -f ${DESTDIR}${BINDIR}/robsd-kill ${DESTDIR}${BINDIR}/robsd-ports-kill
	ln -f ${DESTDIR}${LIBEXECDIR}/robsd/robsd-exec ${DESTDIR}${LIBEXECDIR}/robsd/robsd-ports-exec
	${INSTALL} -m 0555 ${PROG_robsd-exec} ${DESTDIR}${LIBEXECDIR}/robsd
	${INSTALL_MAN} ${.CURDIR}/robsd-ports.8 ${DESTDIR}${MANDIR}/man8
# robsd-regress
	${INSTALL} -m 0555 ${.CURDIR}/robsd-regress ${DESTDIR}${BINDIR}
	ln -f ${DESTDIR}${BINDIR}/robsd-clean ${DESTDIR}${BINDIR}/robsd-regress-clean
	ln -f ${DESTDIR}${BINDIR}/robsd-kill ${DESTDIR}${BINDIR}/robsd-regress-kill
	ln -f ${DESTDIR}${LIBEXECDIR}/robsd/robsd-exec ${DESTDIR}${LIBEXECDIR}/robsd/robsd-regress-exec
	${INSTALL_MAN} ${.CURDIR}/robsd-regress.8 ${DESTDIR}${MANDIR}/man8
# robsd-stat
	${INSTALL} -m 0555 ${PROG_robsd-stat} ${DESTDIR}${LIBEXECDIR}/robsd
	${INSTALL_MAN} ${.CURDIR}/robsd-stat.8 ${DESTDIR}${MANDIR}/man8
.PHONY: install

test: all
	${MAKE} -C ${.CURDIR}/tests \
		"EXECDIR=${.CURDIR}" \
		"ROBSDEXEC=${.OBJDIR}/${PROG_robsd-exec}" \
		"ROBSDSTAT=${.OBJDIR}/${PROG_robsd-stat}" \
		"TESTFLAGS=${TESTFLAGS}"
.PHONY: test

.include "${.CURDIR}/Makefile.inc"
-include ${DEPS_robsd-exec}
-include ${DEPS_robsd-stat}
