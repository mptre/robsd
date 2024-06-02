include ${.CURDIR}/config.mk

VERSION=	20.0.0rc3

COMPATS+=	compat-pledge.c
COMPATS+=	compat-strtonum.c
COMPATS+=	compat-unveil.c

SRCS_config+=	alloc.c
SRCS_config+=	arena-buffer.c
SRCS_config+=	arena-vector.c
SRCS_config+=	arena.c
SRCS_config+=	arithmetic.c
SRCS_config+=	buffer.c
SRCS_config+=	conf.c
SRCS_config+=	conf-canvas.c
SRCS_config+=	conf-robsd.c
SRCS_config+=	conf-robsd-cross.c
SRCS_config+=	conf-robsd-ports.c
SRCS_config+=	conf-robsd-regress.c
SRCS_config+=	if.c
SRCS_config+=	interpolate.c
SRCS_config+=	lexer.c
SRCS_config+=	log.c
SRCS_config+=	mode.c
SRCS_config+=	token.c
SRCS_config+=	variable-value.c
SRCS_config+=	vector.c

SRCS_robsd-config+=	${COMPATS}
SRCS_robsd-config+=	${SRCS_config}
SRCS_robsd-config+=	robsd-config.c
OBJS_robsd-config=	${SRCS_robsd-config:.c=.o}
DEPS_robsd-config=	${SRCS_robsd-config:.c=.d}
PROG_robsd-config=	robsd-config

SRCS_robsd-exec+=	${COMPATS}
SRCS_robsd-exec+=	${SRCS_config}
SRCS_robsd-exec+=	step-exec.c
SRCS_robsd-exec+=	robsd-exec.c
OBJS_robsd-exec=	${SRCS_robsd-exec:.c=.o}
DEPS_robsd-exec=	${SRCS_robsd-exec:.c=.d}
PROG_robsd-exec=	robsd-exec

SRCS_robsd-hook+=	${COMPATS}
SRCS_robsd-hook+=	${SRCS_config}
SRCS_robsd-hook+=	robsd-hook.c
OBJS_robsd-hook=	${SRCS_robsd-hook:.c=.o}
DEPS_robsd-hook=	${SRCS_robsd-hook:.c=.d}
PROG_robsd-hook=	robsd-hook

SRCS_robsd-ls+=		${COMPATS}
SRCS_robsd-ls+=		${SRCS_config}
SRCS_robsd-ls+=		invocation.c
SRCS_robsd-ls+=		robsd-ls.c
OBJS_robsd-ls=		${SRCS_robsd-ls:.c=.o}
DEPS_robsd-ls=		${SRCS_robsd-ls:.c=.d}
PROG_robsd-ls=		robsd-ls

SRCS_robsd-regress-html+=	${COMPATS}
SRCS_robsd-regress-html+=	alloc.c
SRCS_robsd-regress-html+=	arithmetic.c
SRCS_robsd-regress-html+=	arena.c
SRCS_robsd-regress-html+=	arena-buffer.c
SRCS_robsd-regress-html+=	buffer.c
SRCS_robsd-regress-html+=	consistency.c
SRCS_robsd-regress-html+=	html.c
SRCS_robsd-regress-html+=	interpolate.c
SRCS_robsd-regress-html+=	invocation.c
SRCS_robsd-regress-html+=	lexer.c
SRCS_robsd-regress-html+=	log.c
SRCS_robsd-regress-html+=	map.c
SRCS_robsd-regress-html+=	regress-html.c
SRCS_robsd-regress-html+=	regress-log.c
SRCS_robsd-regress-html+=	step.c
SRCS_robsd-regress-html+=	token.c
SRCS_robsd-regress-html+=	vector.c
SRCS_robsd-regress-html+=	robsd-regress-html.c
OBJS_robsd-regress-html=	${SRCS_robsd-regress-html:.c=.o}
DEPS_robsd-regress-html=	${SRCS_robsd-regress-html:.c=.d}
PROG_robsd-regress-html=	robsd-regress-html

SRCS_robsd-regress-log+=	${COMPATS}
SRCS_robsd-regress-log+=	buffer.c
SRCS_robsd-regress-log+=	consistency.c
SRCS_robsd-regress-log+=	regress-log.c
SRCS_robsd-regress-log+=	robsd-regress-log.c
OBJS_robsd-regress-log=		${SRCS_robsd-regress-log:.c=.o}
DEPS_robsd-regress-log=		${SRCS_robsd-regress-log:.c=.d}
PROG_robsd-regress-log=		robsd-regress-log

SRCS_robsd-report+=	${COMPATS}
SRCS_robsd-report+=	${SRCS_config}
SRCS_robsd-report+=	consistency.c
SRCS_robsd-report+=	invocation.c
SRCS_robsd-report+=	map.c
SRCS_robsd-report+=	regress-log.c
SRCS_robsd-report+=	report.c
SRCS_robsd-report+=	step.c
SRCS_robsd-report+=	robsd-report.c
OBJS_robsd-report=	${SRCS_robsd-report:.c=.o}
DEPS_robsd-report=	${SRCS_robsd-report:.c=.d}
PROG_robsd-report=	robsd-report

SRCS_robsd-stat+=	${COMPATS}
SRCS_robsd-stat+=	arena.c
SRCS_robsd-stat+=	vector.c
SRCS_robsd-stat+=	robsd-stat.c
OBJS_robsd-stat=	${SRCS_robsd-stat:.c=.o}
DEPS_robsd-stat=	${SRCS_robsd-stat:.c=.d}
PROG_robsd-stat=	robsd-stat

SRCS_robsd-step+=	${COMPATS}
SRCS_robsd-step+=	${SRCS_config}
SRCS_robsd-step+=	step.c
SRCS_robsd-step+=	robsd-step.c
OBJS_robsd-step=	${SRCS_robsd-step:.c=.o}
DEPS_robsd-step=	${SRCS_robsd-step:.c=.d}
PROG_robsd-step=	robsd-step

SRCS_robsd-wait+=	${COMPATS}
SRCS_robsd-wait+=	arithmetic.c
SRCS_robsd-wait+=	map.c
SRCS_robsd-wait+=	vector.c
SRCS_robsd-wait+=	robsd-wait.c
OBJS_robsd-wait=	${SRCS_robsd-wait:.c=.o}
DEPS_robsd-wait=	${SRCS_robsd-wait:.c=.d}
PROG_robsd-wait=	robsd-wait

SRCS_fuzz-config+=	${COMPATS}
SRCS_fuzz-config+=	${SRCS_config}
SRCS_fuzz-config+=	tmp.c
SRCS_fuzz-config+=	fuzz-config.c
OBJS_fuzz-config=	${SRCS_fuzz-config:.c=.o}
DEPS_fuzz-config=	${SRCS_fuzz-config:.c=.d}
PROG_fuzz-config=	fuzz-config

SRCS_fuzz-step+=	${COMPATS}
SRCS_fuzz-step+=	alloc.c
SRCS_fuzz-step+=	arena-buffer.c
SRCS_fuzz-step+=	arena.c
SRCS_fuzz-step+=	buffer.c
SRCS_fuzz-step+=	interpolate.c
SRCS_fuzz-step+=	lexer.c
SRCS_fuzz-step+=	log.c
SRCS_fuzz-step+=	token.c
SRCS_fuzz-step+=	vector.c
SRCS_fuzz-step+=	step.c
SRCS_fuzz-step+=	tmp.c
SRCS_fuzz-step+=	fuzz-step.c
OBJS_fuzz-step=	${SRCS_fuzz-step:.c=.o}
DEPS_fuzz-step=	${SRCS_fuzz-step:.c=.d}
PROG_fuzz-step=	fuzz-step

KNFMT+=	alloc.c
KNFMT+=	alloc.h
KNFMT+=	conf-canvas.c
KNFMT+=	conf-priv.h
KNFMT+=	conf-robsd-cross.c
KNFMT+=	conf-robsd-ports.c
KNFMT+=	conf-robsd-regress.c
KNFMT+=	conf-robsd.c
KNFMT+=	conf.c
KNFMT+=	conf.h
KNFMT+=	fuzz-config.c
KNFMT+=	fuzz-step.c
KNFMT+=	html.c
KNFMT+=	html.h
KNFMT+=	if.c
KNFMT+=	if.h
KNFMT+=	interpolate.c
KNFMT+=	interpolate.h
KNFMT+=	invocation.c
KNFMT+=	invocation.h
KNFMT+=	lexer.c
KNFMT+=	lexer.h
KNFMT+=	log.c
KNFMT+=	log.h
KNFMT+=	mode.c
KNFMT+=	mode.h
KNFMT+=	regress-html.c
KNFMT+=	regress-html.h
KNFMT+=	regress-log.c
KNFMT+=	regress-log.h
KNFMT+=	report.c
KNFMT+=	report.h
KNFMT+=	robsd-config.c
KNFMT+=	robsd-exec.c
KNFMT+=	robsd-hook.c
KNFMT+=	robsd-ls.c
KNFMT+=	robsd-regress-html.c
KNFMT+=	robsd-regress-log.c
KNFMT+=	robsd-report.c
KNFMT+=	robsd-stat.c
KNFMT+=	robsd-step.c
KNFMT+=	robsd-wait.c
KNFMT+=	step-exec.c
KNFMT+=	step-exec.h
KNFMT+=	step.c
KNFMT+=	step.h
KNFMT+=	token.c
KNFMT+=	token.h
KNFMT+=	variable-value.c
KNFMT+=	variable-value.h

CLANGTIDY+=	alloc.c
CLANGTIDY+=	alloc.h
CLANGTIDY+=	conf-canvas.c
CLANGTIDY+=	conf-priv.h
CLANGTIDY+=	conf-robsd-cross.c
CLANGTIDY+=	conf-robsd-ports.c
CLANGTIDY+=	conf-robsd-regress.c
CLANGTIDY+=	conf-robsd.c
CLANGTIDY+=	conf.c
CLANGTIDY+=	conf.h
CLANGTIDY+=	fuzz-config.c
CLANGTIDY+=	fuzz-step.c
CLANGTIDY+=	html.c
CLANGTIDY+=	html.h
CLANGTIDY+=	if.c
CLANGTIDY+=	if.h
CLANGTIDY+=	interpolate.c
CLANGTIDY+=	interpolate.h
CLANGTIDY+=	invocation.c
CLANGTIDY+=	invocation.h
CLANGTIDY+=	lexer.c
CLANGTIDY+=	lexer.h
CLANGTIDY+=	log.c
CLANGTIDY+=	log.h
CLANGTIDY+=	mode.c
CLANGTIDY+=	mode.h
CLANGTIDY+=	regress-html.c
CLANGTIDY+=	regress-html.h
CLANGTIDY+=	regress-log.c
CLANGTIDY+=	regress-log.h
CLANGTIDY+=	report.c
CLANGTIDY+=	report.h
CLANGTIDY+=	robsd-config.c
CLANGTIDY+=	robsd-exec.c
CLANGTIDY+=	robsd-hook.c
CLANGTIDY+=	robsd-ls.c
CLANGTIDY+=	robsd-regress-html.c
CLANGTIDY+=	robsd-regress-log.c
CLANGTIDY+=	robsd-report.c
CLANGTIDY+=	robsd-stat.c
CLANGTIDY+=	robsd-step.c
CLANGTIDY+=	robsd-wait.c
CLANGTIDY+=	step-exec.c
CLANGTIDY+=	step-exec.h
CLANGTIDY+=	step.c
CLANGTIDY+=	step.h
CLANGTIDY+=	token.c
CLANGTIDY+=	token.h
CLANGTIDY+=	variable-value.c
CLANGTIDY+=	variable-value.h

CPPCHECK+=	alloc.c
CPPCHECK+=	conf-canvas.c
CPPCHECK+=	conf-robsd-cross.c
CPPCHECK+=	conf-robsd-ports.c
CPPCHECK+=	conf-robsd-regress.c
CPPCHECK+=	conf-robsd.c
CPPCHECK+=	conf.c
CPPCHECK+=	fuzz-config.c
CPPCHECK+=	fuzz-step.c
CPPCHECK+=	html.c
CPPCHECK+=	if.c
CPPCHECK+=	interpolate.c
CPPCHECK+=	invocation.c
CPPCHECK+=	lexer.c
CPPCHECK+=	log.c
CPPCHECK+=	mode.c
CPPCHECK+=	regress-html.c
CPPCHECK+=	regress-log.c
CPPCHECK+=	report.c
CPPCHECK+=	robsd-config.c
CPPCHECK+=	robsd-exec.c
CPPCHECK+=	robsd-hook.c
CPPCHECK+=	robsd-ls.c
CPPCHECK+=	robsd-regress-html.c
CPPCHECK+=	robsd-regress-log.c
CPPCHECK+=	robsd-report.c
CPPCHECK+=	robsd-stat.c
CPPCHECK+=	robsd-step.c
CPPCHECK+=	robsd-wait.c
CPPCHECK+=	step-exec.c
CPPCHECK+=	step.c
CPPCHECK+=	token.c
CPPCHECK+=	variable-value.c

CPPCHECKFLAGS+=	--quiet
CPPCHECKFLAGS+=	--check-level=exhaustive
CPPCHECKFLAGS+=	--enable=all
CPPCHECKFLAGS+=	--error-exitcode=1
CPPCHECKFLAGS+=	--max-configs=2
CPPCHECKFLAGS+=	--suppress-xml=cppcheck-suppressions.xml
CPPCHECKFLAGS+=	${CPPFLAGS}

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
SCRIPTS+=	util-ports.sh
SCRIPTS+=	util-regress.sh
SCRIPTS+=	util.sh

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
MANLINT+=	robsd-ls.8
MANLINT+=	robsd-ports.8
MANLINT+=	robsd-ports.conf.5
MANLINT+=	robsd-regress-html.8
MANLINT+=	robsd-regress-log.8
MANLINT+=	robsd-regress.8
MANLINT+=	robsd-regress.conf.5
MANLINT+=	robsd-rescue.8
MANLINT+=	robsd-stat.8
MANLINT+=	robsd-step.8
MANLINT+=	robsd.8
MANLINT+=	robsd.conf.5

SHLINT+=	${SCRIPTS}
SHLINT+=	canvas
SHLINT+=	configure
SHLINT+=	robsd
SHLINT+=	robsd-clean
SHLINT+=	robsd-cross
SHLINT+=	robsd-crossenv
SHLINT+=	robsd-kill
SHLINT+=	robsd-ports
SHLINT+=	robsd-regress
SHLINT+=	robsd-rescue
SHLINT+=	tests/canvas-robsd-config.sh
SHLINT+=	tests/canvas.sh
SHLINT+=	tests/check-perf.sh
SHLINT+=	tests/cleandir.sh
SHLINT+=	tests/config-load.sh
SHLINT+=	tests/cvs-log.sh
SHLINT+=	tests/diff-apply.sh
SHLINT+=	tests/diff-clean.sh
SHLINT+=	tests/diff-copy.sh
SHLINT+=	tests/diff-list.sh
SHLINT+=	tests/diff-root.sh
SHLINT+=	tests/duration-total.sh
SHLINT+=	tests/lock-acquire.sh
SHLINT+=	tests/log-id.sh
SHLINT+=	tests/purge.sh
SHLINT+=	tests/regress-failed.sh
SHLINT+=	tests/robsd-config.sh
SHLINT+=	tests/robsd-cross.sh
SHLINT+=	tests/robsd-crossenv.sh
SHLINT+=	tests/robsd-exec.sh
SHLINT+=	tests/robsd-hash.sh
SHLINT+=	tests/robsd-hook.sh
SHLINT+=	tests/robsd-ls.sh
SHLINT+=	tests/robsd-ports.sh
SHLINT+=	tests/robsd-regress-html.sh
SHLINT+=	tests/robsd-regress-log.sh
SHLINT+=	tests/robsd-regress-obj.sh
SHLINT+=	tests/robsd-regress-pkg-add.sh
SHLINT+=	tests/robsd-regress.sh
SHLINT+=	tests/robsd-report.sh
SHLINT+=	tests/robsd-rescue.sh
SHLINT+=	tests/robsd-step.sh
SHLINT+=	tests/robsd-wait.sh
SHLINT+=	tests/robsd.sh
SHLINT+=	tests/step-eval.sh
SHLINT+=	tests/step-id.sh
SHLINT+=	tests/step-next.sh
SHLINT+=	tests/step-time.sh
SHLINT+=	tests/step-value.sh
SHLINT+=	tests/step-write.sh
SHLINT+=	tests/util.sh

SHELLCHECKFLAGS+=	-f gcc
SHELLCHECKFLAGS+=	-s ksh
SHELLCHECKFLAGS+=	-e SC1090			# non-constant source
SHELLCHECKFLAGS+=	-e SC1091			# not following source
SHELLCHECKFLAGS+=	-e SC2012			# find instead of ls
SHELLCHECKFLAGS+=	-e SC2164			# cd failure
SHELLCHECKFLAGS+=	-o add-default-case
SHELLCHECKFLAGS+=	-o avoid-nullary-conditions
SHELLCHECKFLAGS+=	-o quote-safe-variables

all: ${PROG_robsd-config}
all: ${PROG_robsd-exec}
all: ${PROG_robsd-hook}
all: ${PROG_robsd-ls}
all: ${PROG_robsd-regress-html}
all: ${PROG_robsd-regress-log}
all: ${PROG_robsd-report}
all: ${PROG_robsd-stat}
all: ${PROG_robsd-step}
all: ${PROG_robsd-wait}

${PROG_robsd-config}: ${OBJS_robsd-config}
	${CC} ${DEBUG} -o ${PROG_robsd-config} ${OBJS_robsd-config} ${LDFLAGS}

${PROG_robsd-exec}: ${OBJS_robsd-exec}
	${CC} ${DEBUG} -o ${PROG_robsd-exec} ${OBJS_robsd-exec} ${LDFLAGS}

${PROG_robsd-hook}: ${OBJS_robsd-hook}
	${CC} ${DEBUG} -o ${PROG_robsd-hook} ${OBJS_robsd-hook} ${LDFLAGS}

${PROG_robsd-ls}: ${OBJS_robsd-ls}
	${CC} ${DEBUG} -o ${PROG_robsd-ls} ${OBJS_robsd-ls} ${LDFLAGS}

${PROG_robsd-regress-html}: ${OBJS_robsd-regress-html}
	${CC} ${DEBUG} -o ${PROG_robsd-regress-html} ${OBJS_robsd-regress-html} ${LDFLAGS}

${PROG_robsd-regress-log}: ${OBJS_robsd-regress-log}
	${CC} ${DEBUG} -o ${PROG_robsd-regress-log} ${OBJS_robsd-regress-log} ${LDFLAGS}

${PROG_robsd-report}: ${OBJS_robsd-report}
	${CC} ${DEBUG} -o ${PROG_robsd-report} ${OBJS_robsd-report} ${LDFLAGS}

${PROG_robsd-stat}: ${OBJS_robsd-stat}
	${CC} ${DEBUG} -o ${PROG_robsd-stat} ${OBJS_robsd-stat} ${LDFLAGS}

${PROG_robsd-step}: ${OBJS_robsd-step}
	${CC} ${DEBUG} -o ${PROG_robsd-step} ${OBJS_robsd-step} ${LDFLAGS}

${PROG_robsd-wait}: ${OBJS_robsd-wait}
	${CC} ${DEBUG} -o ${PROG_robsd-wait} ${OBJS_robsd-wait} ${LDFLAGS}

clean:
	rm -f \
		${DEPS_robsd-config} ${OBJS_robsd-config} ${PROG_robsd-config} \
		${DEPS_robsd-exec} ${OBJS_robsd-exec} ${PROG_robsd-exec} \
		${DEPS_robsd-hook} ${OBJS_robsd-hook} ${PROG_robsd-hook} \
		${DEPS_robsd-ls} ${OBJS_robsd-ls} ${PROG_robsd-ls} \
		${DEPS_robsd-regress-html} ${OBJS_robsd-regress-html} ${PROG_robsd-regress-html} \
		${DEPS_robsd-regress-log} ${OBJS_robsd-regress-log} ${PROG_robsd-regress-log} \
		${DEPS_robsd-report} ${OBJS_robsd-report} ${PROG_robsd-report} \
		${DEPS_robsd-stat} ${OBJS_robsd-stat} ${PROG_robsd-stat} \
		${DEPS_robsd-step} ${OBJS_robsd-step} ${PROG_robsd-step} \
		${DEPS_robsd-wait} ${OBJS_robsd-wait} ${PROG_robsd-wait} \
		${DEPS_fuzz-config} ${OBJS_fuzz-config} ${PROG_fuzz-config} \
		${DEPS_fuzz-step} ${OBJS_fuzz-step} ${PROG_fuzz-step}
.PHONY: clean

cleandir: clean
	cd ${.CURDIR} && rm -f config.h config.log config.mk
.PHONY: cleandir

dist:
	set -e; p=robsd-${VERSION}; cd ${.CURDIR}; \
	git archive --output $$p.tar.gz --prefix $$p/ v${VERSION}; \
	sha256 $$p.tar.gz >$$p.sha256
.PHONY: dist

format:
	cd ${.CURDIR} && knfmt -is ${KNFMT}
.PHONY: format

fuzz: ${PROG_fuzz-config} ${PROG_fuzz-step}

${PROG_fuzz-config}: ${OBJS_fuzz-config}
	${CC} ${DEBUG} -o ${PROG_fuzz-config} ${OBJS_fuzz-config} ${LDFLAGS}

${PROG_fuzz-step}: ${OBJS_fuzz-step}
	${CC} ${DEBUG} -o ${PROG_fuzz-step} ${OBJS_fuzz-step} ${LDFLAGS}

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
# robsd-ls
	${INSTALL} -m 0555 ${PROG_robsd-ls} ${DESTDIR}${LIBEXECDIR}/robsd
	${INSTALL_MAN} ${.CURDIR}/robsd-ls.8 ${DESTDIR}${MANDIR}/man8
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
# robsd-ports
	${INSTALL} -m 0555 ${.CURDIR}/robsd-ports ${DESTDIR}${BINDIR}
	${INSTALL_MAN} ${.CURDIR}/robsd-ports.conf.5 ${DESTDIR}${MANDIR}/man5
	${INSTALL_MAN} ${.CURDIR}/robsd-ports.8 ${DESTDIR}${MANDIR}/man8
	ln -f ${DESTDIR}${BINDIR}/robsd-clean ${DESTDIR}${BINDIR}/robsd-ports-clean
	ln -f ${DESTDIR}${BINDIR}/robsd-kill ${DESTDIR}${BINDIR}/robsd-ports-kill
	ln -f ${DESTDIR}${BINDIR}/robsd-rescue ${DESTDIR}${BINDIR}/robsd-ports-rescue
# robsd-regress
	${INSTALL} -m 0555 ${.CURDIR}/robsd-regress ${DESTDIR}${BINDIR}
	${INSTALL_MAN} ${.CURDIR}/robsd-regress.conf.5 ${DESTDIR}${MANDIR}/man5
	${INSTALL_MAN} ${.CURDIR}/robsd-regress.8 ${DESTDIR}${MANDIR}/man8
	ln -f ${DESTDIR}${BINDIR}/robsd-clean ${DESTDIR}${BINDIR}/robsd-regress-clean
	ln -f ${DESTDIR}${BINDIR}/robsd-kill ${DESTDIR}${BINDIR}/robsd-regress-kill
# robsd-regress-html
	${INSTALL} -m 0555 ${PROG_robsd-regress-html} ${DESTDIR}${BINDIR}
	${INSTALL_MAN} ${.CURDIR}/robsd-regress-html.8 ${DESTDIR}${MANDIR}/man8
# robsd-regress-log
	${INSTALL} -m 0555 ${PROG_robsd-regress-log} ${DESTDIR}${LIBEXECDIR}/robsd
	${INSTALL_MAN} ${.CURDIR}/robsd-regress-log.8 ${DESTDIR}${MANDIR}/man8
# robsd-report
	${INSTALL} -m 0555 ${PROG_robsd-report} ${DESTDIR}${LIBEXECDIR}/robsd
# robsd-wait
	${INSTALL} -m 0555 ${PROG_robsd-wait} ${DESTDIR}${LIBEXECDIR}/robsd
# canvas
	${INSTALL} -m 0555 ${.CURDIR}/canvas ${DESTDIR}${PREFIX}/bin
.PHONY: install

lint:
	cd ${.CURDIR} && knfmt -ds ${KNFMT}
	cd ${.CURDIR} && mandoc -Tlint -Wstyle ${MANLINT}
.PHONY: lint

lint-clang-tidy:
	cd ${.CURDIR} && echo ${CLANGTIDY} | xargs printf '%s\n' | \
		xargs -I{} clang-tidy --quiet {} -- \
		${CPPFLAGS}
.PHONY: lint-clang-tidy

lint-cppcheck:
	cd ${.CURDIR} && cppcheck ${CPPCHECKFLAGS} ${CPPCHECK}
.PHONY: lint-cppcheck

IWYU?=	include-what-you-use
lint-include-what-you-use:
	cd ${.CURDIR} && echo ${CPPCHECK} | xargs printf '%s\n' | \
		xargs -I{} ${IWYU} ${CPPFLAGS} {}
.PHONY: lint-include-what-you-use

NCPU!!?=	sysctl -n hw.ncpuonline
lint-shellcheck:
	cd ${.CURDIR} && echo ${SHLINT} | \
	xargs -n1 -P${NCPU} shellcheck ${SHELLCHECKFLAGS}
.PHONY: lint-shellcheck

test: all
	${MAKE} -C ${.CURDIR}/tests \
		"EXECDIR=${.CURDIR}" \
		"ROBSDCONFIG=${.OBJDIR}/${PROG_robsd-config}" \
		"ROBSDEXEC=${.OBJDIR}/${PROG_robsd-exec}" \
		"ROBSDHOOK=${.OBJDIR}/${PROG_robsd-hook}" \
		"ROBSDLS=${.OBJDIR}/${PROG_robsd-ls}" \
		"ROBSDREGRESSHTML=${.OBJDIR}/${PROG_robsd-regress-html}" \
		"ROBSDREGRESSLOG=${.OBJDIR}/${PROG_robsd-regress-log}" \
		"ROBSDREPORT=${.OBJDIR}/${PROG_robsd-report}" \
		"ROBSDSTAT=${.OBJDIR}/${PROG_robsd-stat}" \
		"ROBSDSTEP=${.OBJDIR}/${PROG_robsd-step}" \
		"ROBSDWAIT=${.OBJDIR}/${PROG_robsd-wait}" \
		"TESTFLAGS=${TESTFLAGS}"
.PHONY: test

-include ${DEPS_robsd-config}
-include ${DEPS_robsd-exec}
-include ${DEPS_robsd-hook}
-include ${DEPS_robsd-ls}
-include ${DEPS_robsd-regress-html}
-include ${DEPS_robsd-regress-log}
-include ${DEPS_robsd-report}
-include ${DEPS_robsd-stat}
-include ${DEPS_robsd-step}
-include ${DEPS_robsd-wait}
-include ${DEPS_fuzz-config}
-include ${DEPS_fuzz-step}
