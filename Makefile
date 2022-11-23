include ${.CURDIR}/config.mk

VERSION=	17.1.0

PROG_robsd-config=	robsd-config
SRCS_robsd-config+=	robsd-config.c
SRCS_robsd-config+=	buffer.c
SRCS_robsd-config+=	config.c
SRCS_robsd-config+=	compat-errc.c
SRCS_robsd-config+=	compat-pledge.c
SRCS_robsd-config+=	compat-warnc.c
SRCS_robsd-config+=	interpolate.c
SRCS_robsd-config+=	lexer.c
SRCS_robsd-config+=	token.c
SRCS_robsd-config+=	util.c
SRCS_robsd-config+=	vector.c
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
SRCS_robsd-hook+=	interpolate.c
SRCS_robsd-hook+=	lexer.c
SRCS_robsd-hook+=	token.c
SRCS_robsd-hook+=	util.c
SRCS_robsd-hook+=	vector.c
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
SRCS_robsd-stat+=	compat-strlcpy.c
OBJS_robsd-stat=	${SRCS_robsd-stat:.c=.o}
DEPS_robsd-stat=	${SRCS_robsd-stat:.c=.d}

PROG_robsd-step=	robsd-step
SRCS_robsd-step+=	robsd-step.c
SRCS_robsd-step+=	buffer.c
SRCS_robsd-step+=	compat-pledge.c
SRCS_robsd-step+=	compat-strtonum.c
SRCS_robsd-step+=	compat-unveil.c
SRCS_robsd-step+=	interpolate.c
SRCS_robsd-step+=	lexer.c
SRCS_robsd-step+=	step.c
SRCS_robsd-step+=	token.c
SRCS_robsd-step+=	util.c
SRCS_robsd-step+=	vector.c
OBJS_robsd-step=	${SRCS_robsd-step:.c=.o}
DEPS_robsd-step=	${SRCS_robsd-step:.c=.d}

KNFMT+=	buffer.c
KNFMT+=	buffer.h
KNFMT+=	cdefs.h
KNFMT+=	compat-sys-sched.h
KNFMT+=	compat-sys-sysctl.h
KNFMT+=	config.c
KNFMT+=	extern.h
KNFMT+=	interpolate.c
KNFMT+=	interpolate.h
KNFMT+=	lexer.c
KNFMT+=	lexer.h
KNFMT+=	robsd-config.c
KNFMT+=	robsd-exec.c
KNFMT+=	robsd-hook.c
KNFMT+=	robsd-regress-log.c
KNFMT+=	robsd-stat.c
KNFMT+=	robsd-step.c
KNFMT+=	step.c
KNFMT+=	step.h
KNFMT+=	token.c
KNFMT+=	token.h
KNFMT+=	util.c
KNFMT+=	util.h
KNFMT+=	vector.c
KNFMT+=	vector.h

CLANGTIDY+=	buffer.c
CLANGTIDY+=	buffer.h
CLANGTIDY+=	cdefs.h
CLANGTIDY+=	config.c
CLANGTIDY+=	extern.h
CLANGTIDY+=	interpolate.c
CLANGTIDY+=	interpolate.h
CLANGTIDY+=	lexer.c
CLANGTIDY+=	lexer.h
CLANGTIDY+=	robsd-config.c
CLANGTIDY+=	robsd-exec.c
CLANGTIDY+=	robsd-hook.c
CLANGTIDY+=	robsd-regress-log.c
CLANGTIDY+=	robsd-stat.c
CLANGTIDY+=	robsd-step.c
CLANGTIDY+=	step.c
CLANGTIDY+=	step.h
CLANGTIDY+=	token.c
CLANGTIDY+=	token.h
CLANGTIDY+=	util.c
CLANGTIDY+=	util.h
CLANGTIDY+=	vector.c
CLANGTIDY+=	vector.h

CPPCHECK+=	buffer.c
CPPCHECK+=	config.c
CPPCHECK+=	interpolate.c
CPPCHECK+=	lexer.c
CPPCHECK+=	robsd-config.c
CPPCHECK+=	robsd-exec.c
CPPCHECK+=	robsd-hook.c
CPPCHECK+=	robsd-regress-log.c
CPPCHECK+=	robsd-stat.c
CPPCHECK+=	robsd-step.c
CPPCHECK+=	step.c
CPPCHECK+=	token.c
CPPCHECK+=	util.c

SCRIPTS+=	robsd-base.sh
SCRIPTS+=	robsd-checkflist.sh
SCRIPTS+=	robsd-cross-dirs.sh
SCRIPTS+=	robsd-cross-distrib.sh
SCRIPTS+=	robsd-cross-tools.sh
SCRIPTS+=	robsd-cvs.sh
SCRIPTS+=	robsd-distrib.sh
SCRIPTS+=	robsd-dmesg.sh
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
SCRIPTS+=	robsd-regress-obj.sh
SCRIPTS+=	robsd-regress-pkg-add.sh
SCRIPTS+=	robsd-regress-pkg-del.sh
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
DISTFILES+=	buffer.h
DISTFILES+=	cdefs.h
DISTFILES+=	compat-errc.c
DISTFILES+=	compat-pledge.c
DISTFILES+=	compat-strlcpy.c
DISTFILES+=	compat-strtonum.c
DISTFILES+=	compat-sys-sched.h
DISTFILES+=	compat-sys-sysctl.h
DISTFILES+=	compat-unveil.c
DISTFILES+=	compat-warnc.c
DISTFILES+=	config.c
DISTFILES+=	configure
DISTFILES+=	extern.h
DISTFILES+=	interpolate.c
DISTFILES+=	interpolate.h
DISTFILES+=	lexer.c
DISTFILES+=	lexer.h
DISTFILES+=	robsd
DISTFILES+=	robsd-base.sh
DISTFILES+=	robsd-checkflist.sh
DISTFILES+=	robsd-clean
DISTFILES+=	robsd-clean.8
DISTFILES+=	robsd-config.8
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
DISTFILES+=	robsd-dmesg.sh
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
DISTFILES+=	robsd-regress-obj.sh
DISTFILES+=	robsd-regress-pkg-add.sh
DISTFILES+=	robsd-regress-pkg-del.sh
DISTFILES+=	robsd-regress-umount.sh
DISTFILES+=	robsd-regress.8
DISTFILES+=	robsd-regress.conf.5
DISTFILES+=	robsd-release.sh
DISTFILES+=	robsd-rescue
DISTFILES+=	robsd-rescue.8
DISTFILES+=	robsd-revert.sh
DISTFILES+=	robsd-stat.8
DISTFILES+=	robsd-stat.c
DISTFILES+=	robsd-step.8
DISTFILES+=	robsd-step.c
DISTFILES+=	robsd-xbase.sh
DISTFILES+=	robsd-xrelease.sh
DISTFILES+=	robsd.8
DISTFILES+=	robsd.conf.5
DISTFILES+=	step.c
DISTFILES+=	step.h
DISTFILES+=	tests/Makefile
DISTFILES+=	tests/check-perf.sh
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
DISTFILES+=	tests/robsd-hash.sh
DISTFILES+=	tests/robsd-hook.sh
DISTFILES+=	tests/robsd-ports.sh
DISTFILES+=	tests/robsd-regress.sh
DISTFILES+=	tests/robsd-rescue.sh
DISTFILES+=	tests/robsd-step.sh
DISTFILES+=	tests/robsd.sh
DISTFILES+=	tests/step-end.sh
DISTFILES+=	tests/step-eval.sh
DISTFILES+=	tests/step-id.sh
DISTFILES+=	tests/step-next.sh
DISTFILES+=	tests/step-time.sh
DISTFILES+=	tests/step-value.sh
DISTFILES+=	tests/t.sh
DISTFILES+=	tests/util.sh
DISTFILES+=	token.c
DISTFILES+=	token.h
DISTFILES+=	util-cross.sh
DISTFILES+=	util-ports.sh
DISTFILES+=	util-regress.sh
DISTFILES+=	util.c
DISTFILES+=	util.h
DISTFILES+=	util.sh
DISTFILES+=	vector.c
DISTFILES+=	vector.h

PREFIX=		/usr/local
BINDIR=		${PREFIX}/sbin
LIBEXECDIR=	${PREFIX}/libexec
MANDIR=		${PREFIX}/man
INSTALL?=	install
INSTALL_MAN?=	${INSTALL}

MANLINT+=	robsd-clean.8
MANLINT+=	robsd-config.8
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
MANLINT+=	robsd-step.8
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
all: ${PROG_robsd-regress-log} ${PROG_robsd-stat} ${PROG_robsd-step}

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

${PROG_robsd-step}: ${OBJS_robsd-step}
	${CC} ${DEBUG} -o ${PROG_robsd-step} ${OBJS_robsd-step} ${LDFLAGS}

clean:
	rm -f \
		${DEPS_robsd-config} ${OBJS_robsd-config} ${PROG_robsd-config} \
		${DEPS_robsd-exec} ${OBJS_robsd-exec} ${PROG_robsd-exec} \
		${DEPS_robsd-hook} ${OBJS_robsd-hook} ${PROG_robsd-hook} \
		${DEPS_robsd-regress-log} ${OBJS_robsd-regress-log} ${PROG_robsd-regress-log} \
		${DEPS_robsd-stat} ${OBJS_robsd-stat} ${PROG_robsd-stat} \
		${DEPS_robsd-step} ${OBJS_robsd-step} ${PROG_robsd-step}
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
	${INSTALL_MAN} ${.CURDIR}/robsd-config.8 ${DESTDIR}${MANDIR}/man8
# robsd-exec
	${INSTALL} -m 0555 ${PROG_robsd-exec} ${DESTDIR}${LIBEXECDIR}/robsd
# robsd-hook
	${INSTALL} -m 0555 ${PROG_robsd-hook} ${DESTDIR}${LIBEXECDIR}/robsd
	${INSTALL_MAN} ${.CURDIR}/robsd-hook.5 ${DESTDIR}${MANDIR}/man5
# robsd-stat
	${INSTALL} -m 0555 ${PROG_robsd-stat} ${DESTDIR}${LIBEXECDIR}/robsd
	${INSTALL_MAN} ${.CURDIR}/robsd-stat.8 ${DESTDIR}${MANDIR}/man8
# robsd-step
	${INSTALL} -m 0555 ${PROG_robsd-step} ${DESTDIR}${LIBEXECDIR}/robsd
	${INSTALL_MAN} ${.CURDIR}/robsd-step.8 ${DESTDIR}${MANDIR}/man8
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
	ln -f ${DESTDIR}${BINDIR}/robsd-rescue ${DESTDIR}${BINDIR}/robsd-ports-rescue
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

lint-clang-tidy:
	cd ${.CURDIR} && clang-tidy --quiet ${CLANGTIDY}
.PHONY: lint-clang-tidy

lint-cppcheck:
	cd ${.CURDIR} && cppcheck --quiet --enable=all --error-exitcode=1 \
		--max-configs=2 --suppress-xml=cppcheck-suppressions.xml \
		${CPPCHECK}
.PHONY: lint-cppcheck

test: all
	${MAKE} -C ${.CURDIR}/tests \
		"EXECDIR=${.CURDIR}" \
		"ROBSDCONFIG=${.OBJDIR}/${PROG_robsd-config}" \
		"ROBSDEXEC=${.OBJDIR}/${PROG_robsd-exec}" \
		"ROBSDHOOK=${.OBJDIR}/${PROG_robsd-hook}" \
		"ROBSDREGRESSLOG=${.OBJDIR}/${PROG_robsd-regress-log}" \
		"ROBSDSTAT=${.OBJDIR}/${PROG_robsd-stat}" \
		"ROBSDSTEP=${.OBJDIR}/${PROG_robsd-step}" \
		"TESTFLAGS=${TESTFLAGS}"
.PHONY: test

INC?=	${.CURDIR}/Makefile.inc
include ${INC}

-include ${DEPS_robsd-config}
-include ${DEPS_robsd-exec}
-include ${DEPS_robsd-hook}
-include ${DEPS_robsd-regress-log}
-include ${DEPS_robsd-stat}
-include ${DEPS_robsd-step}
