LOGDIR="${TSHDIR}/logdir"
STEPS="${TSHDIR}/steps"
REPORT="${TSHDIR}/report"

# genfile size path
#
# Generate a file located at path of the given size expressed in MB.
genfile() {
	local _s="$1" _p="$2"

	dd if=/dev/zero "of=${_p}" "bs=$((_s * 1024 * 1024))" count=1 2>/dev/null
}

if testcase "basic"; then
	BSDDIFF=""; export BSDDIFF
	XDIFF=""; export XDIFF
	LOGDIR="${BUILDDIR}/2019-02-23"
	# shellcheck disable=SC2086
	mkdir -p ${BUILDDIR}/2019-02-{22,23}
	echo "comment goes here" >"${LOGDIR}/comment"
	echo "cvs log" >"${LOGDIR}/cvs.log"
	cat <<-EOF >"${LOGDIR}/steps"
	step="1" name="env" exit="0" duration="0" log="${LOGDIR}/env.log" user="root" time="0"
	step="2" name="cvs" exit="0" duration="358" log="${LOGDIR}/cvs.log" user="root" time="0"
	step="3" name="patch" exit="0" duration="0" log="${LOGDIR}/patch.log" user="root" time="0"
	step="4" name="kernel" skip="1"
	step="5" name="end" exit="0" duration="3600" log="" user="root" time="0"
	EOF
	mkdir "${LOGDIR}/rel"
	genfile 2 "${LOGDIR}/rel/bsd.rd"
	genfile 1 "${LOGDIR}/rel/base66.tgz"

	# Create a previous release in order to report duration and sizes.
	cat <<-EOF >"${BUILDDIR}/2019-02-22/steps"
	step="2" name="cvs" exit="0" duration="298" log="/dev/null" user="root" time="0"
	EOF
	mkdir "${BUILDDIR}/2019-02-22/rel"
	genfile 1 "${BUILDDIR}/2019-02-22/rel/bsd.rd"
	genfile 1 "${BUILDDIR}/2019-02-22/rel/base66.tgz"

	cat <<-EOF >"$TMP1"
	Subject: robsd: $(hostname -s): ok

	> comment:
	comment goes here

	> stats:
	Status: ok
	Duration: 01:00:00
	Build: ${LOGDIR}
	Size: bsd.rd 2.0M (+1.0M)

	> cvs:
	Exit: 0
	Duration: 00:05:58 (+00:01:00)
	Log: cvs.log

	cvs log
	EOF

	report -r "$REPORT" -s "${LOGDIR}/steps"

	assert_file "$TMP1" "$REPORT"
fi

if testcase "failure"; then
	mkdir "$LOGDIR"
	echo "cvs log" >"${LOGDIR}/cvs.log"
	cat <<-EOF >"$STEPS"
	step="1" name="env" exit="0" duration="1" log="${LOGDIR}/env.log" user="root" time="0"
	step="2" name="cvs" exit="1" duration="10" log="${LOGDIR}/cvs.log" user="root" time="0"
	step="3" name="patch" skip="1"
	EOF
	cat <<-EOF >"$TMP1"
	Subject: robsd: $(hostname -s): failed in cvs

	> stats:
	Status: failed in cvs
	Duration: 00:00:11
	Build: ${LOGDIR}

	> cvs:
	Exit: 1
	Duration: 00:00:10
	Log: cvs.log

	cvs log
	EOF

	report -r "$REPORT" -s "$STEPS"

	assert_file "$TMP1" "$REPORT"
fi

if testcase "failure in skipped step"; then
	mkdir "$LOGDIR"
	echo "env log" >"${LOGDIR}/env.log"
	cat <<-EOF >"$STEPS"
	step="1" name="env" exit="1" duration="1" log="${LOGDIR}/env.log" user="root" time="0"
	EOF
	cat <<-EOF >"$TMP1"
	Subject: robsd: $(hostname -s): failed in env

	> stats:
	Status: failed in env
	Duration: 00:00:01
	Build: ${LOGDIR}

	> env:
	Exit: 1
	Duration: 00:00:01
	Log: env.log

	env log
	EOF

	report -r "$REPORT" -s "$STEPS"

	assert_file "$TMP1" "$REPORT"
fi

if testcase "missing step"; then
	if report -r "$REPORT" -s "$STEPS"; then
		fail "want exit 1, got 0"
	fi
fi
