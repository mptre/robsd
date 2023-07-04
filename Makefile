include ${.CURDIR}/config.mk

VERSION=	17.8.0rc1

SRCS+=	alloc.c
SRCS+=	arithmetic.c
SRCS+=	buffer.c
SRCS+=	compat-pledge.c
SRCS+=	compat-strtonum.c
SRCS+=	compat-unveil.c
SRCS+=	compat-warnc.c
SRCS+=	conf.c
SRCS+=	html.c
SRCS+=	interpolate.c
SRCS+=	invocation.c
SRCS+=	lexer.c
SRCS+=	map.c
SRCS+=	regress-html.c
SRCS+=	regress-log.c
SRCS+=	step.c
SRCS+=	token.c
SRCS+=	util.c
SRCS+=	vector.c

SRCS_robsd-config+=	${SRCS}
SRCS_robsd-config+=	robsd-config.c
OBJS_robsd-config=	${SRCS_robsd-config:.c=.o}
DEPS_robsd-config=	${SRCS_robsd-config:.c=.d}
PROG_robsd-config=	robsd-config

SRCS_robsd-exec+=	${SRCS}
SRCS_robsd-exec+=	robsd-exec.c
OBJS_robsd-exec=	${SRCS_robsd-exec:.c=.o}
DEPS_robsd-exec=	${SRCS_robsd-exec:.c=.d}
PROG_robsd-exec=	robsd-exec

SRCS_robsd-hook+=	${SRCS}
SRCS_robsd-hook+=	robsd-hook.c
OBJS_robsd-hook=	${SRCS_robsd-hook:.c=.o}
DEPS_robsd-hook=	${SRCS_robsd-hook:.c=.d}
PROG_robsd-hook=	robsd-hook

SRCS_robsd-ls+=		${SRCS}
SRCS_robsd-ls+=		robsd-ls.c
OBJS_robsd-ls=		${SRCS_robsd-ls:.c=.o}
DEPS_robsd-ls=		${SRCS_robsd-ls:.c=.d}
PROG_robsd-ls=		robsd-ls

SRCS_robsd-regress-html+=	${SRCS}
SRCS_robsd-regress-html+=	robsd-regress-html.c
OBJS_robsd-regress-html=	${SRCS_robsd-regress-html:.c=.o}
DEPS_robsd-regress-html=	${SRCS_robsd-regress-html:.c=.d}
PROG_robsd-regress-html=	robsd-regress-html

SRCS_robsd-regress-log+=	${SRCS}
SRCS_robsd-regress-log+=	robsd-regress-log.c
OBJS_robsd-regress-log=		${SRCS_robsd-regress-log:.c=.o}
DEPS_robsd-regress-log=		${SRCS_robsd-regress-log:.c=.d}
PROG_robsd-regress-log=		robsd-regress-log

SRCS_robsd-stat+=	${SRCS}
SRCS_robsd-stat+=	robsd-stat.c
OBJS_robsd-stat=	${SRCS_robsd-stat:.c=.o}
DEPS_robsd-stat=	${SRCS_robsd-stat:.c=.d}
PROG_robsd-stat=	robsd-stat

SRCS_robsd-step+=	${SRCS}
SRCS_robsd-step+=	robsd-step.c
OBJS_robsd-step=	${SRCS_robsd-step:.c=.o}
DEPS_robsd-step=	${SRCS_robsd-step:.c=.d}
PROG_robsd-step=	robsd-step

SRCS_fuzz-config+=	${SRCS}
SRCS_fuzz-config+=	fuzz-config.c
OBJS_fuzz-config=	${SRCS_fuzz-config:.c=.o}
DEPS_fuzz-config=	${SRCS_fuzz-config:.c=.d}
PROG_fuzz-config=	fuzz-config

KNFMT+=	alloc.c
KNFMT+=	alloc.h
KNFMT+=	cdefs.h
KNFMT+=	conf.c
KNFMT+=	conf.h
KNFMT+=	fuzz-config.c
KNFMT+=	html.c
KNFMT+=	html.h
KNFMT+=	interpolate.c
KNFMT+=	interpolate.h
KNFMT+=	invocation.c
KNFMT+=	invocation.h
KNFMT+=	lexer.c
KNFMT+=	lexer.h
KNFMT+=	regress-html.c
KNFMT+=	regress-html.h
KNFMT+=	regress-log.c
KNFMT+=	regress-log.h
KNFMT+=	robsd-config.c
KNFMT+=	robsd-exec.c
KNFMT+=	robsd-hook.c
KNFMT+=	robsd-ls.c
KNFMT+=	robsd-regress-html.c
KNFMT+=	robsd-regress-log.c
KNFMT+=	robsd-stat.c
KNFMT+=	robsd-step.c
KNFMT+=	step.c
KNFMT+=	step.h
KNFMT+=	token.c
KNFMT+=	token.h
KNFMT+=	util.c
KNFMT+=	util.h

CLANGTIDY+=	alloc.c
CLANGTIDY+=	alloc.h
CLANGTIDY+=	cdefs.h
CLANGTIDY+=	conf.c
CLANGTIDY+=	conf.h
CLANGTIDY+=	fuzz-config.c
CLANGTIDY+=	html.c
CLANGTIDY+=	html.h
CLANGTIDY+=	interpolate.c
CLANGTIDY+=	interpolate.h
CLANGTIDY+=	invocation.c
CLANGTIDY+=	invocation.h
CLANGTIDY+=	lexer.c
CLANGTIDY+=	lexer.h
CLANGTIDY+=	regress-html.c
CLANGTIDY+=	regress-html.h
CLANGTIDY+=	regress-log.c
CLANGTIDY+=	regress-log.h
CLANGTIDY+=	robsd-config.c
CLANGTIDY+=	robsd-exec.c
CLANGTIDY+=	robsd-hook.c
CLANGTIDY+=	robsd-ls.c
CLANGTIDY+=	robsd-regress-html.c
CLANGTIDY+=	robsd-regress-log.c
CLANGTIDY+=	robsd-stat.c
CLANGTIDY+=	robsd-step.c
CLANGTIDY+=	step.c
CLANGTIDY+=	step.h
CLANGTIDY+=	token.c
CLANGTIDY+=	token.h
CLANGTIDY+=	util.c
CLANGTIDY+=	util.h

CPPCHECK+=	alloc.c
CPPCHECK+=	conf.c
CPPCHECK+=	fuzz-config.c
CPPCHECK+=	html.c
CPPCHECK+=	interpolate.c
CPPCHECK+=	invocation.c
CPPCHECK+=	lexer.c
CPPCHECK+=	regress-html.c
CPPCHECK+=	regress-log.c
CPPCHECK+=	robsd-config.c
CPPCHECK+=	robsd-exec.c
CPPCHECK+=	robsd-hook.c
CPPCHECK+=	robsd-ls.c
CPPCHECK+=	robsd-regress-html.c
CPPCHECK+=	robsd-regress-log.c
CPPCHECK+=	robsd-stat.c
CPPCHECK+=	robsd-step.c
CPPCHECK+=	step.c
CPPCHECK+=	token.c
CPPCHECK+=	util.c

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
SCRIPTS+=	util-cross.sh
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
SHLINT+=	configure
SHLINT+=	robsd
SHLINT+=	robsd-clean
SHLINT+=	robsd-cross
SHLINT+=	robsd-crossenv
SHLINT+=	robsd-kill
SHLINT+=	robsd-ports
SHLINT+=	robsd-regress
SHLINT+=	robsd-rescue

SUBDIR+=	tests

all: ${PROG_robsd-config}
all: ${PROG_robsd-exec}
all: ${PROG_robsd-hook}
all: ${PROG_robsd-ls}
all: ${PROG_robsd-regress-html}
all: ${PROG_robsd-regress-log}
all: ${PROG_robsd-stat}
all: ${PROG_robsd-step}

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

${PROG_robsd-stat}: ${OBJS_robsd-stat}
	${CC} ${DEBUG} -o ${PROG_robsd-stat} ${OBJS_robsd-stat} ${LDFLAGS}

${PROG_robsd-step}: ${OBJS_robsd-step}
	${CC} ${DEBUG} -o ${PROG_robsd-step} ${OBJS_robsd-step} ${LDFLAGS}

clean:
	rm -f \
		${DEPS_robsd-config} ${OBJS_robsd-config} ${PROG_robsd-config} \
		${DEPS_robsd-exec} ${OBJS_robsd-exec} ${PROG_robsd-exec} \
		${DEPS_robsd-hook} ${OBJS_robsd-hook} ${PROG_robsd-hook} \
		${DEPS_robsd-ls} ${OBJS_robsd-ls} ${PROG_robsd-ls} \
		${DEPS_robsd-regress-html} ${OBJS_robsd-regress-html} ${PROG_robsd-regress-html} \
		${DEPS_robsd-regress-log} ${OBJS_robsd-regress-log} ${PROG_robsd-regress-log} \
		${DEPS_robsd-stat} ${OBJS_robsd-stat} ${PROG_robsd-stat} \
		${DEPS_robsd-step} ${OBJS_robsd-step} ${PROG_robsd-step}
.PHONY: clean

cleandir: clean
	cd ${.CURDIR} && rm -f config.h config.log config.mk
.PHONY: cleandir

dist:
	set -e; p=robsd-${VERSION}; cd ${.CURDIR}; \
	git archive --output $$p.tar.gz --prefix $$p/ v${VERSION}; \
	sha256 $$p.tar.gz >$$p.sha256
.PHONY: dist

fuzz: ${PROG_fuzz-config}

${PROG_fuzz-config}: ${OBJS_fuzz-config}
	${CC} ${DEBUG} -o ${PROG_fuzz-config} ${OBJS_fuzz-config} ${LDFLAGS}

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
# robsd-regress-html
	${INSTALL} -m 0555 ${PROG_robsd-regress-html} ${DESTDIR}${BINDIR}
	${INSTALL_MAN} ${.CURDIR}/robsd-regress-html.8 ${DESTDIR}${MANDIR}/man8
# robsd-regress-log
	${INSTALL} -m 0555 ${PROG_robsd-regress-log} ${DESTDIR}${LIBEXECDIR}/robsd
	${INSTALL_MAN} ${.CURDIR}/robsd-regress-log.8 ${DESTDIR}${MANDIR}/man8
.PHONY: install

lint-clang-tidy:
	cd ${.CURDIR} && echo ${CLANGTIDY} | xargs printf '%s\n' | \
		xargs -I{} clang-tidy --quiet {} -- ${CPPFLAGS}
.PHONY: lint-clang-tidy

lint-cppcheck:
	cd ${.CURDIR} && cppcheck ${CPPCHECKFLAGS} ${CPPCHECK}
.PHONY: lint-cppcheck

IWYU?=	include-what-you-use
lint-include-what-you-use:
	cd ${.CURDIR} && echo ${CPPCHECK} | xargs printf '%s\n' | \
		xargs -I{} ${IWYU} ${CPPFLAGS} {}
.PHONY: lint-include-what-you-use

test: all
	${MAKE} -C ${.CURDIR}/tests \
		"EXECDIR=${.CURDIR}" \
		"ROBSDCONFIG=${.OBJDIR}/${PROG_robsd-config}" \
		"ROBSDEXEC=${.OBJDIR}/${PROG_robsd-exec}" \
		"ROBSDHOOK=${.OBJDIR}/${PROG_robsd-hook}" \
		"ROBSDLS=${.OBJDIR}/${PROG_robsd-ls}" \
		"ROBSDREGRESSHTML=${.OBJDIR}/${PROG_robsd-regress-html}" \
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
-include ${DEPS_robsd-ls}
-include ${DEPS_robsd-regress-html}
-include ${DEPS_robsd-regress-log}
-include ${DEPS_robsd-stat}
-include ${DEPS_robsd-step}
