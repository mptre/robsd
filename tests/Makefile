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
TESTS+=	log-id.sh
TESTS+=	prev-release.sh
TESTS+=	purge.sh
TESTS+=	report-duration.sh
TESTS+=	report-size.sh
TESTS+=	report-skip.sh
TESTS+=	report.sh
TESTS+=	step-end.sh
TESTS+=	step-eval.sh
TESTS+=	step-id.sh
TESTS+=	step-next.sh

SHLINT+=	${TESTS:C/^/${.CURDIR}\//}
SHLINT+=	${.CURDIR}/util.sh

all: test

test: ${TESTS:.sh=.fake}

.SUFFIXES: .sh .fake

.sh.fake:
	sh ${.CURDIR}/t.sh ${TESTFLAGS} ${.CURDIR}/util.sh ${.CURDIR}/$<

.include "${.CURDIR}/../Makefile.inc"
