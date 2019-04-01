TESTS+=	build-duration.sh
TESTS+=	cleandir.sh
TESTS+=	diff-root.sh
TESTS+=	format-duration.sh
TESTS+=	purge.sh
TESTS+=	report-duration.sh
TESTS+=	report-recipients.sh
TESTS+=	report-size.sh
TESTS+=	stage-eval.sh
TESTS+=	stage-next.sh

all: test

test: ${TESTS:.sh=.fake}

.SUFFIXES: .sh .fake

.sh.fake:
	sh ${.CURDIR}/t.sh ${TESTFLAGS} ${.CURDIR}/util.sh ${.CURDIR}/$<
