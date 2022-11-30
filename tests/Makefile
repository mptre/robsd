TESTS+=	check-perf.sh
TESTS+=	cleandir.sh
TESTS+=	config-load.sh
TESTS+=	cvs-log.sh
TESTS+=	diff-apply.sh
TESTS+=	diff-clean.sh
TESTS+=	diff-copy.sh
TESTS+=	diff-list.sh
TESTS+=	diff-root.sh
TESTS+=	duration-total.sh
TESTS+=	format-duration.sh
TESTS+=	lock-acquire.sh
TESTS+=	log-id.sh
TESTS+=	ports-report-log.sh
TESTS+=	purge.sh
TESTS+=	regress-failed.sh
TESTS+=	regress-report-log.sh
TESTS+=	report-duration.sh
TESTS+=	report-size.sh
TESTS+=	report-skip.sh
TESTS+=	report.sh
TESTS+=	robsd-config.sh
TESTS+=	robsd-cross.sh
TESTS+=	robsd-crossenv.sh
TESTS+=	robsd-hash.sh
TESTS+=	robsd-hook.sh
TESTS+=	robsd-ls.sh
TESTS+=	robsd-ports.sh
TESTS+=	robsd-regress.sh
TESTS+=	robsd-rescue.sh
TESTS+=	robsd-step.sh
TESTS+=	robsd.sh
TESTS+=	step-end.sh
TESTS+=	step-eval.sh
TESTS+=	step-id.sh
TESTS+=	step-next.sh
TESTS+=	step-time.sh
TESTS+=	step-value.sh

SHLINT+=	${TESTS}
SHLINT+=	util.sh

all: test

test: ${TESTS:.sh=.fake}

.SUFFIXES: .sh .fake

.sh.fake:
	sh ${.CURDIR}/t.sh ${TESTFLAGS} ${.CURDIR}/util.sh ${.CURDIR}/$<

INC?=	${.CURDIR}/../Makefile.inc
include ${INC}
