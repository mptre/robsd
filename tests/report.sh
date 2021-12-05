BUILDDIR="${ROBSDDIR}/2019-02-23"
STEPS="${BUILDDIR}/steps"
REPORT="${BUILDDIR}/report"

# genfile size path
#
# Generate a file located at path of the given size expressed in MB.
genfile() {
	local _s="$1" _p="$2"

	dd if=/dev/zero "of=${_p}" "bs=$((_s * 1024 * 1024))" count=1 2>/dev/null
}

if testcase "basic"; then
	# Create a previous release in order to report duration deltas.
	build_init "${ROBSDDIR}/2019-02-21"
	cat <<-EOF >"${ROBSDDIR}/2019-02-21/steps"
	step="2" name="cvs" exit="0" duration="30" log="/dev/null" user="root" time="0"
	EOF

	# Create a previous release in order to report size deltas.
	build_init "${ROBSDDIR}/2019-02-22"
	cat <<-EOF >"${ROBSDDIR}/2019-02-22/steps"
	step="2" name="cvs" skip="1"
	EOF
	mkdir "${ROBSDDIR}/2019-02-22/rel"
	genfile 1 "${ROBSDDIR}/2019-02-22/rel/bsd.rd"
	genfile 1 "${ROBSDDIR}/2019-02-22/rel/base66.tgz"

	build_init "$BUILDDIR"
	BSDDIFF=""; export BSDDIFF
	XDIFF=""; export XDIFF
	echo "daily" >"${BUILDDIR}/tags"
	echo "comment goes here" >"${BUILDDIR}/comment"
	echo "cvs src update" >"${BUILDDIR}/tmp/cvs-src-up.log"
	echo "cvs src commits" >"${BUILDDIR}/tmp/cvs-src-ci.log"
	cat <<-EOF >"${BUILDDIR}/steps"
	step="1" name="env" exit="0" duration="0" log="${BUILDDIR}/env.log" user="root" time="0"
	step="2" name="cvs" exit="0" duration="60" log="${BUILDDIR}/cvs.log" user="root" time="0"
	step="3" name="patch" exit="0" duration="0" log="${BUILDDIR}/patch.log" user="root" time="0"
	step="4" name="kernel" skip="1"
	step="5" name="end" exit="0" duration="3600" log="" user="root" time="0"
	EOF
	mkdir "${BUILDDIR}/rel"
	genfile 2 "${BUILDDIR}/rel/bsd.rd"
	genfile 1 "${BUILDDIR}/rel/base66.tgz"

	cat <<-EOF >"$TMP1"
	Subject: robsd: $(hostname -s): ok

	> comment:
	comment goes here

	> stats:
	Status: ok
	Duration: 01:00:00
	Build: ${BUILDDIR}
	Tags: daily
	Size: bsd.rd 2.0M (+1.0M)

	> cvs:
	Exit: 0
	Duration: 00:01:00 (+00:00:30)
	Log: cvs.log

	cvs src update

	cvs src commits
	EOF

	report -b "$BUILDDIR"

	assert_file "$TMP1" "$REPORT"
fi

if testcase "failure"; then
	build_init "$BUILDDIR"
	echo "env log" >"${BUILDDIR}/env.log"
	echo "cvs log" >"${BUILDDIR}/cvs.log"
	cat <<-EOF >"$STEPS"
	step="1" name="cvs" exit="0" duration="11" log="${BUILDDIR}/cvs.log" user="root" time="0"
	step="2" name="env" exit="1" duration="10" log="${BUILDDIR}/env.log" user="root" time="0"
	step="3" name="patch" skip="1"
	EOF
	cat <<-EOF >"$TMP1"
	Subject: robsd: $(hostname -s): failed in env

	> stats:
	Status: failed in env
	Duration: 00:00:21
	Build: ${BUILDDIR}

	> cvs:
	Exit: 0
	Duration: 00:00:11
	Log: cvs.log

	> env:
	Exit: 1
	Duration: 00:00:10
	Log: env.log

	env log
	EOF

	report -b "$BUILDDIR"

	assert_file "$TMP1" "$REPORT"
fi

if testcase "failure in skipped step"; then
	build_init "$BUILDDIR"
	echo "env log" >"${BUILDDIR}/env.log"
	cat <<-EOF >"$STEPS"
	step="1" name="env" exit="1" duration="1" log="${BUILDDIR}/env.log" user="root" time="0"
	EOF
	cat <<-EOF >"$TMP1"
	Subject: robsd: $(hostname -s): failed in env

	> stats:
	Status: failed in env
	Duration: 00:00:01
	Build: ${BUILDDIR}

	> env:
	Exit: 1
	Duration: 00:00:01
	Log: env.log

	env log
	EOF

	report -b "$BUILDDIR"

	assert_file "$TMP1" "$REPORT"
fi

if testcase "missing step"; then
	if report -b "$BUILDDIR"; then
		fail "want exit 1, got 0"
	fi
fi

if testcase "regress"; then
	build_init "$BUILDDIR"
	cat <<-EOF >"${BUILDDIR}/nein.log"
	==== t0 ====
	skip
	SKIPPED

	==== t1 ====
	failure
	FAILED

	==== t2 ====
	success
	EOF
	cat <<-EOF >"${BUILDDIR}/skipped.log"
	discard me...

	===> test
	SKIPPED
	EOF
	cat <<-EOF >"${BUILDDIR}/error.log"
	cc -O2 -pipe  -Wall  -MD -MP  -c log.c
	error: unable to open output file 'log.o': 'Read-only file system'
	EOF
	cat <<-EOF >"$STEPS"
	step="1" name="skipped" exit="0" duration="10" log="${BUILDDIR}/skipped.log" user="root" time="0"
	step="2" name="nein" exit="1" duration="1" log="${BUILDDIR}/nein.log" user="root" time="0"
	step="3" name="error" exit="1" duration="1" log="${BUILDDIR}/error.log" user="root" time="0"
	step="4" name="end" exit="0" duration="12" log="" user="root" time="0"
	EOF

	(setmode "robsd-regress" && report -b "$BUILDDIR")

	assert_file - "$REPORT" <<-EOF
	Subject: robsd-regress: $(hostname -s): 2 failures

	> stats:
	Status: 2 failures
	Duration: 00:00:12
	Build: ${BUILDDIR}

	> skipped:
	Exit: 0
	Duration: 00:00:10
	Log: skipped.log

	===> test
	SKIPPED

	> nein:
	Exit: 1
	Duration: 00:00:01
	Log: nein.log

	==== t0 ====
	skip
	SKIPPED

	==== t1 ====
	failure
	FAILED

	> error:
	Exit: 1
	Duration: 00:00:01
	Log: error.log

	cc -O2 -pipe  -Wall  -MD -MP  -c log.c
	error: unable to open output file 'log.o': 'Read-only file system'
	EOF
fi

if testcase "ports"; then
	build_init "${ROBSDDIR}/2019-02-21"
	cat <<-EOF >"${ROBSDDIR}/2019-02-21/steps"
	step="1" name="mail/mdsort" exit="0" duration="10" log="/dev/null" user="root" time="0"
	EOF

	build_init "${ROBSDDIR}/2019-02-22"
	cat <<-EOF >"${ROBSDDIR}/2019-02-22/steps"
	step="1" name="mail/mdsort" exit="1" duration="1" log="/dev/null" user="root" time="0"
	EOF

	build_init "$BUILDDIR"
	cat <<-EOF >"$STEPS"
	step="1" name="mail/mdsort" exit="0" duration="20" log="mail-mdsort.log" user="root" time="0"
	EOF

	# shellcheck disable=SC2034
	(PORTS="mail/mdsort"; setmode "robsd-ports" && report -b "$BUILDDIR")

	assert_file - "$REPORT" <<-EOF
	Subject: robsd-ports: $(hostname -s): ok

	> stats:
	Status: ok
	Duration: 00:00:20
	Build: ${BUILDDIR}

	> mail/mdsort:
	Exit: 0
	Duration: 00:00:20 (+00:00:10)
	Log: mail-mdsort.log
	EOF
fi
