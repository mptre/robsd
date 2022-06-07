include ${.CURDIR}/config.mk

VERSION=	12.0.0

PROG_robsd-config=	robsd-config
SRCS_robsd-config+=	robsd-config.c
SRCS_robsd-config+=	buffer.c
SRCS_robsd-config+=	config.c
SRCS_robsd-config+=	compat-errc.c
SRCS_robsd-config+=	compat-pledge.c
SRCS_robsd-config+=	compat-warnc.c
SRCS_robsd-config+=	util.c
OBJS_robsd-config=	${SRCS_robsd-config:.c=.o}
DEPS_robsd-config=	${SRCS_robsd-config:.c=.d}

PROG_robsd-exec=	robsd-exec
SRCS_robsd-exec+=	robsd-exec.c
SRCS_robsd-exec+=	compat-pledge.c
OBJS_robsd-exec=	${SRCS_robsd-exec:.c=.o}
DEPS_robsd-exec=	${SRCS_robsd-exec:.c=.d}

PROG_robsd-hook=	robsd-hook
SRCS_robsd-hook+=	robsd-hook.c
SRCS_robsd-hook+=	buffer.c
SRCS_robsd-hook+=	config.c
SRCS_robsd-hook+=	compat-errc.c
SRCS_robsd-hook+=	compat-pledge.c
SRCS_robsd-hook+=	compat-warnc.c
SRCS_robsd-hook+=	util.c
OBJS_robsd-hook=	${SRCS_robsd-hook:.c=.o}
DEPS_robsd-hook=	${SRCS_robsd-hook:.c=.d}

PROG_robsd-regress-log=		robsd-regress-log
SRCS_robsd-regress-log+=	robsd-regress-log.c
SRCS_robsd-regress-log+=	buffer.c
SRCS_robsd-regress-log+=	compat-pledge.c
SRCS_robsd-regress-log+=	compat-unveil.c
OBJS_robsd-regress-log=		${SRCS_robsd-regress-log:.c=.o}
DEPS_robsd-regress-log=		${SRCS_robsd-regress-log:.c=.d}

PROG_robsd-stat=	robsd-stat
SRCS_robsd-stat+=	robsd-stat.c
OBJS_robsd-stat=	${SRCS_robsd-stat:.c=.o}
DEPS_robsd-stat=	${SRCS_robsd-stat:.c=.d}

KNFMT+=	buffer.c
KNFMT+=	config.c
KNFMT+=	extern.h
KNFMT+=	robsd-config.c
KNFMT+=	robsd-exec.c
KNFMT+=	robsd-hook.c
KNFMT+=	robsd-regress-log.c
KNFMT+=	robsd-stat.c
KNFMT+=	util.c

SCRIPTS+=	robsd-base.sh
SCRIPTS+=	robsd-checkflist.sh
SCRIPTS+=	robsd-cross-dirs.sh
SCRIPTS+=	robsd-cross-distrib.sh
SCRIPTS+=	robsd-cross-tools.sh
SCRIPTS+=	robsd-cvs.sh
SCRIPTS+=	robsd-distrib.sh
SCRIPTS+=	robsd-env.sh
SCRIPTS+=	robsd-hash.sh
SCRIPTS+=	robsd-image.sh
SCRIPTS+=	robsd-kernel.sh
SCRIPTS+=	robsd-patch.sh
SCRIPTS+=	robsd-ports-clean.sh
SCRIPTS+=	robsd-ports-distrib.sh
SCRIPTS+=	robsd-ports-dpb.sh
SCRIPTS+=	robsd-ports-proot.sh
SCRIPTS+=	robsd-reboot.sh
SCRIPTS+=	robsd-regress-exec.sh
SCRIPTS+=	robsd-regress-mount.sh
SCRIPTS+=	robsd-regress-umount.sh
SCRIPTS+=	robsd-release.sh
SCRIPTS+=	robsd-revert.sh
SCRIPTS+=	robsd-xbase.sh
SCRIPTS+=	robsd-xrelease.sh
SCRIPTS+=	util-cross.sh
SCRIPTS+=	util-ports.sh
SCRIPTS+=	util-regress.sh
SCRIPTS+=	util.sh

DISTFILES+=	CHANGELOG.md
DISTFILES+=	LICENSE
DISTFILES+=	Makefile
DISTFILES+=	Makefile.inc
DISTFILES+=	README.md
DISTFILES+=	buffer.c
DISTFILES+=	compat-errc.c
DISTFILES+=	compat-pledge.c
DISTFILES+=	compat-strlcpy.c
DISTFILES+=	compat-unveil.c
DISTFILES+=	compat-warnc.c
DISTFILES+=	config.c
DISTFILES+=	configure
DISTFILES+=	extern.h
DISTFILES+=	robsd
DISTFILES+=	robsd-base.sh
DISTFILES+=	robsd-checkflist.sh
DISTFILES+=	robsd-clean
DISTFILES+=	robsd-clean.8
DISTFILES+=	robsd-config.c
DISTFILES+=	robsd-cross
DISTFILES+=	robsd-cross-dirs.sh
DISTFILES+=	robsd-cross-distrib.sh
DISTFILES+=	robsd-cross-tools.sh
DISTFILES+=	robsd-cross.8
DISTFILES+=	robsd-cross.conf.5
DISTFILES+=	robsd-crossenv
DISTFILES+=	robsd-crossenv.8
DISTFILES+=	robsd-cvs.sh
DISTFILES+=	robsd-distrib.sh
DISTFILES+=	robsd-env.sh
DISTFILES+=	robsd-exec.c
DISTFILES+=	robsd-hash.sh
DISTFILES+=	robsd-hook.5
DISTFILES+=	robsd-hook.c
DISTFILES+=	robsd-image.sh
DISTFILES+=	robsd-kernel.sh
DISTFILES+=	robsd-kill
DISTFILES+=	robsd-kill.8
DISTFILES+=	robsd-patch.sh
DISTFILES+=	robsd-ports
DISTFILES+=	robsd-ports-clean.sh
DISTFILES+=	robsd-ports-distrib.sh
DISTFILES+=	robsd-ports-dpb.sh
DISTFILES+=	robsd-ports-proot.sh
DISTFILES+=	robsd-ports.8
DISTFILES+=	robsd-ports.conf.5
DISTFILES+=	robsd-reboot.sh
DISTFILES+=	robsd-regress
DISTFILES+=	robsd-regress-exec.sh
DISTFILES+=	robsd-regress-log.c
DISTFILES+=	robsd-regress-mount.sh
DISTFILES+=	robsd-regress-umount.sh
DISTFILES+=	robsd-regress.8
DISTFILES+=	robsd-regress.conf.5
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
DISTFILES+=	tests/check-perf.sh
DISTFILES+=	tests/cleandir.sh
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
DISTFILES+=	tests/prev-release.sh
DISTFILES+=	tests/purge.sh
DISTFILES+=	tests/regress-failed.sh
DISTFILES+=	tests/regress-report-log.sh
DISTFILES+=	tests/report-duration.sh
DISTFILES+=	tests/report-size.sh
DISTFILES+=	tests/report-skip.sh
DISTFILES+=	tests/report.sh
DISTFILES+=	tests/robsd-config.sh
DISTFILES+=	tests/robsd-cross.sh
DISTFILES+=	tests/robsd-crossenv.sh
DISTFILES+=	tests/robsd-hook.sh
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
DISTFILES+=	util-cross.sh
DISTFILES+=	util-ports.sh
DISTFILES+=	util-regress.sh
DISTFILES+=	util.c
DISTFILES+=	util.sh

PREFIX=		/usr/local
BINDIR=		${PREFIX}/sbin
LIBEXECDIR=	${PREFIX}/libexec
MANDIR=		${PREFIX}/man
INSTALL?=	install
INSTALL_MAN?=	${INSTALL}

MANLINT+=	robsd-clean.8
MANLINT+=	robsd-cross.8
MANLINT+=	robsd-cross.conf.5
MANLINT+=	robsd-crossenv.8
MANLINT+=	robsd-hook.5
MANLINT+=	robsd-ports.8
MANLINT+=	robsd-ports.conf.5
MANLINT+=	robsd-regress.8
MANLINT+=	robsd-regress.conf.5
MANLINT+=	robsd-rescue.8
MANLINT+=	robsd-stat.8
MANLINT+=	robsd.8
MANLINT+=	robsd.conf.5

SHLINT+=	${SCRIPTS}
SHLINT+=	robsd
SHLINT+=	robsd-clean
SHLINT+=	robsd-cross
SHLINT+=	robsd-crossenv
SHLINT+=	robsd-kill
SHLINT+=	robsd-ports
SHLINT+=	robsd-regress
SHLINT+=	robsd-rescue

SUBDIR+=	tests

all: ${PROG_robsd-config} ${PROG_robsd-hook} ${PROG_robsd-exec}
all: ${PROG_robsd-stat} ${PROG_robsd-regress-log}

${PROG_robsd-config}: ${OBJS_robsd-config}
	${CC} ${DEBUG} -o ${PROG_robsd-config} ${OBJS_robsd-config} ${LDFLAGS}

${PROG_robsd-hook}: ${OBJS_robsd-hook}
	${CC} ${DEBUG} -o ${PROG_robsd-hook} ${OBJS_robsd-hook} ${LDFLAGS}

${PROG_robsd-exec}: ${OBJS_robsd-exec}
	${CC} ${DEBUG} -o ${PROG_robsd-exec} ${OBJS_robsd-exec} ${LDFLAGS}

${PROG_robsd-regress-log}: ${OBJS_robsd-regress-log}
	${CC} ${DEBUG} -o ${PROG_robsd-regress-log} ${OBJS_robsd-regress-log} ${LDFLAGS}

${PROG_robsd-stat}: ${OBJS_robsd-stat}
	${CC} ${DEBUG} -o ${PROG_robsd-stat} ${OBJS_robsd-stat} ${LDFLAGS}

clean:
	rm -f \
		${DEPS_robsd-config} ${OBJS_robsd-config} ${PROG_robsd-config} \
		${DEPS_robsd-exec} ${OBJS_robsd-exec} ${PROG_robsd-exec} \
		${DEPS_robsd-hook} ${OBJS_robsd-hook} ${PROG_robsd-hook} \
		${DEPS_robsd-regress-log} ${OBJS_robsd-regress-log} ${PROG_robsd-regress-log} \
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
	cd ${.CURDIR} && ${INSTALL} -m 0444 ${SCRIPTS} ${DESTDIR}${LIBEXECDIR}/robsd
	@mkdir -p ${DESTDIR}${MANDIR}/man5
	${INSTALL_MAN} ${.CURDIR}/robsd.conf.5 ${DESTDIR}${MANDIR}/man5
	@mkdir -p ${DESTDIR}${MANDIR}/man8
	${INSTALL_MAN} ${.CURDIR}/robsd.8 ${DESTDIR}${MANDIR}/man8
	${INSTALL_MAN} ${.CURDIR}/robsd-clean.8 ${DESTDIR}${MANDIR}/man8
	${INSTALL_MAN} ${.CURDIR}/robsd-kill.8 ${DESTDIR}${MANDIR}/man8
	${INSTALL_MAN} ${.CURDIR}/robsd-rescue.8 ${DESTDIR}${MANDIR}/man8
# robsd-config
	${INSTALL} -m 0555 ${PROG_robsd-config} ${DESTDIR}${LIBEXECDIR}/robsd
# robsd-exec
	${INSTALL} -m 0555 ${PROG_robsd-exec} ${DESTDIR}${LIBEXECDIR}/robsd
# robsd-hook
	${INSTALL} -m 0555 ${PROG_robsd-hook} ${DESTDIR}${LIBEXECDIR}/robsd
	${INSTALL_MAN} ${.CURDIR}/robsd-hook.5 ${DESTDIR}${MANDIR}/man5
# robsd-stat
	${INSTALL} -m 0555 ${PROG_robsd-stat} ${DESTDIR}${LIBEXECDIR}/robsd
	${INSTALL_MAN} ${.CURDIR}/robsd-stat.8 ${DESTDIR}${MANDIR}/man8
# robsd-cross
	${INSTALL} -m 0555 ${.CURDIR}/robsd-cross ${DESTDIR}${BINDIR}
	${INSTALL} -m 0555 ${.CURDIR}/robsd-crossenv ${DESTDIR}${BINDIR}
	${INSTALL_MAN} ${.CURDIR}/robsd-cross.conf.5 ${DESTDIR}${MANDIR}/man5
	${INSTALL_MAN} ${.CURDIR}/robsd-cross.8 ${DESTDIR}${MANDIR}/man8
	${INSTALL_MAN} ${.CURDIR}/robsd-crossenv.8 ${DESTDIR}${MANDIR}/man8
	ln -f ${DESTDIR}${BINDIR}/robsd-clean ${DESTDIR}${BINDIR}/robsd-cross-clean
	ln -f ${DESTDIR}${BINDIR}/robsd-kill ${DESTDIR}${BINDIR}/robsd-cross-kill
	ln -f ${DESTDIR}${LIBEXECDIR}/robsd/robsd-exec ${DESTDIR}${LIBEXECDIR}/robsd/robsd-cross-exec
# robsd-ports
	${INSTALL} -m 0555 ${.CURDIR}/robsd-ports ${DESTDIR}${BINDIR}
	${INSTALL_MAN} ${.CURDIR}/robsd-ports.conf.5 ${DESTDIR}${MANDIR}/man5
	${INSTALL_MAN} ${.CURDIR}/robsd-ports.8 ${DESTDIR}${MANDIR}/man8
	ln -f ${DESTDIR}${BINDIR}/robsd-clean ${DESTDIR}${BINDIR}/robsd-ports-clean
	ln -f ${DESTDIR}${BINDIR}/robsd-kill ${DESTDIR}${BINDIR}/robsd-ports-kill
	ln -f ${DESTDIR}${LIBEXECDIR}/robsd/robsd-exec ${DESTDIR}${LIBEXECDIR}/robsd/robsd-ports-exec
# robsd-regress
	${INSTALL} -m 0555 ${.CURDIR}/robsd-regress ${DESTDIR}${BINDIR}
	${INSTALL_MAN} ${.CURDIR}/robsd-regress.conf.5 ${DESTDIR}${MANDIR}/man5
	${INSTALL_MAN} ${.CURDIR}/robsd-regress.8 ${DESTDIR}${MANDIR}/man8
	ln -f ${DESTDIR}${BINDIR}/robsd-clean ${DESTDIR}${BINDIR}/robsd-regress-clean
	ln -f ${DESTDIR}${BINDIR}/robsd-kill ${DESTDIR}${BINDIR}/robsd-regress-kill
	ln -f ${DESTDIR}${LIBEXECDIR}/robsd/robsd-exec ${DESTDIR}${LIBEXECDIR}/robsd/robsd-regress-exec
# robsd-regress-log
	${INSTALL} -m 0555 ${PROG_robsd-regress-log} ${DESTDIR}${LIBEXECDIR}/robsd
.PHONY: install

test: all
	${MAKE} -C ${.CURDIR}/tests \
		"EXECDIR=${.CURDIR}" \
		"ROBSDCONFIG=${.OBJDIR}/${PROG_robsd-config}" \
		"ROBSDEXEC=${.OBJDIR}/${PROG_robsd-exec}" \
		"ROBSDHOOK=${.OBJDIR}/${PROG_robsd-hook}" \
		"ROBSDREGRESSLOG=${.OBJDIR}/${PROG_robsd-regress-log}" \
		"ROBSDSTAT=${.OBJDIR}/${PROG_robsd-stat}" \
		"TESTFLAGS=${TESTFLAGS}"
.PHONY: test

include ${.CURDIR}/Makefile.inc
-include ${DEPS_robsd-config}
-include ${DEPS_robsd-exec}
-include ${DEPS_robsd-hook}
-include ${DEPS_robsd-regress-log}
-include ${DEPS_robsd-stat}
