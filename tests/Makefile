TESTS+=	cleandir.sh
TESTS+=	comment.sh
TESTS+=	cvs-log.sh
TESTS+=	diff-clean.sh
TESTS+=	diff-copy.sh
TESTS+=	diff-root.sh
TESTS+=	duration-total.sh
TESTS+=	format-duration.sh
TESTS+=	purge.sh
TESTS+=	report-duration.sh
TESTS+=	report-size.sh
TESTS+=	report-skip.sh
TESTS+=	report.sh
TESTS+=	step-eval.sh
TESTS+=	step-next.sh

all: test

test: ${TESTS:.sh=.fake}

.SUFFIXES: .sh .fake

.sh.fake:
	sh ${.CURDIR}/t.sh ${TESTFLAGS} ${.CURDIR}/util.sh ${.CURDIR}/$<
