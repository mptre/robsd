TESTS+=	canvas-robsd-config.sh
TESTS+=	canvas.sh
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
TESTS+=	lock-acquire.sh
TESTS+=	log-id.sh
TESTS+=	purge.sh
TESTS+=	regress-failed.sh
TESTS+=	robsd-config.sh
TESTS+=	robsd-cross.sh
TESTS+=	robsd-crossenv.sh
TESTS+=	robsd-exec.sh
TESTS+=	robsd-hash.sh
TESTS+=	robsd-hook.sh
TESTS+=	robsd-ls.sh
TESTS+=	robsd-ports.sh
TESTS+=	robsd-regress-html.sh
TESTS+=	robsd-regress-log.sh
TESTS+=	robsd-regress-obj.sh
TESTS+=	robsd-regress-pkg-add.sh
TESTS+=	robsd-regress.sh
TESTS+=	robsd-report.sh
TESTS+=	robsd-rescue.sh
TESTS+=	robsd-step.sh
TESTS+=	robsd-wait.sh
TESTS+=	robsd.sh
TESTS+=	step-eval.sh
TESTS+=	step-id.sh
TESTS+=	step-next.sh
TESTS+=	step-time.sh
TESTS+=	step-value.sh
TESTS+=	step-write.sh

all: test

test: ${TESTS:.sh=.fake}

.SUFFIXES: .sh .fake

.sh.fake:
	sh ${.CURDIR}/t.sh ${TESTFLAGS} ${.CURDIR}/util.sh ${.CURDIR}/$<
