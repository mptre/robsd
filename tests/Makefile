TESTS+=	cleandir.sh
TESTS+=	comment.sh
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
TESTS+=	prev-release.sh
TESTS+=	purge.sh
TESTS+=	regress-failed.sh
TESTS+=	regress-tests.sh
TESTS+=	report-duration.sh
TESTS+=	report-size.sh
TESTS+=	report-skip.sh
TESTS+=	report.sh
TESTS+=	robsd-regress.sh
TESTS+=	robsd-rescue.sh
TESTS+=	robsd-steps.sh
TESTS+=	robsd.sh
TESTS+=	step-end.sh
TESTS+=	step-eval.sh
TESTS+=	step-id.sh
TESTS+=	step-next.sh
TESTS+=	step-value.sh

SHLINT+=	${TESTS}
SHLINT+=	util.sh

all: test

test: ${TESTS:.sh=.fake}

.SUFFIXES: .sh .fake

.sh.fake:
	sh ${.CURDIR}/t.sh ${TESTFLAGS} ${.CURDIR}/util.sh ${.CURDIR}/$<

.include "${.CURDIR}/../Makefile.inc"
