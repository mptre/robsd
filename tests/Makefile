TESTS+=	cleandir.sh
TESTS+=	diff-root.sh
TESTS+=	report-recipients.sh
TESTS+=	stage-eval.sh

all: test

test: ${TESTS}

.for t in ${TESTS}
$t:
	sh ${.CURDIR}/t.sh ${TESTFLAGS} ${.CURDIR}/util.sh ${.CURDIR}/$t
.PHONY: $t
.endfor
