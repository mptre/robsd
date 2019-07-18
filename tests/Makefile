TESTS+=	cleandir.sh
TESTS+=	diff-clean.sh
TESTS+=	diff-copy.sh
TESTS+=	diff-root.sh
TESTS+=	duration-total.sh
TESTS+=	format-duration.sh
TESTS+=	purge.sh
TESTS+=	report-duration.sh
TESTS+=	report-size.sh
TESTS+=	report.sh
TESTS+=	stage-eval.sh
TESTS+=	stage-next.sh

all: test

test: ${TESTS:.sh=.fake}

.SUFFIXES: .sh .fake

.sh.fake:
	sh ${.CURDIR}/t.sh ${TESTFLAGS} ${.CURDIR}/util.sh ${.CURDIR}/$<
