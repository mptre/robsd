TESTS+=	diff-root
TESTS+=	stage-eval

all: test

test: ${TESTS}

.for t in ${TESTS}
$t:
	env RELEASEDIR=${RELEASEDIR} sh ${.CURDIR}/t.sh ${.CURDIR}/$t.sh
.PHONY: $t
.endfor
