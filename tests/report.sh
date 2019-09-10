LOGDIR="${TSHDIR}/logdir"
STAGES="${TSHDIR}/stages"
REPORT="${TSHDIR}/report"

# genfile size path
#
# Generate a file located at path of the given size expressed in MB.
genfile() {
	local _s="$1" _p="$2"

	dd if=/dev/zero "of=${_p}" "bs=$((_s * 1024 * 1024))" count=1 2>/dev/null
}

if testcase "basic"; then
	LOGDIR="${BUILDDIR}/2019-02-23"
	mkdir -p ${BUILDDIR}/2019-02-{22,23}
	echo "comment goes here" >"${LOGDIR}/comment"
	echo "cvs log" >"${LOGDIR}/cvs.log"
	cat <<-EOF >${LOGDIR}/stages
	stage="1" name="env" exit="0" duration="0" log="${LOGDIR}/env.log" user="root" time="0"
	stage="2" name="cvs" exit="0" duration="358" log="${LOGDIR}/cvs.log" user="root" time="0"
	stage="3" name="end" exit="0" duration="3600" log="" user="root" time="0"
	EOF
	mkdir "${LOGDIR}/reldir"
	genfile 2 "${LOGDIR}/reldir/bsd.rd"
	genfile 1 "${LOGDIR}/reldir/base66.tgz"

	# Create a previous release in order to report duration and sizes.
	cat <<-EOF >${BUILDDIR}/2019-02-22/stages
	stage="2" name="cvs" exit="0" duration="298" log="/dev/null" user="root" time="0"
	EOF
	mkdir "${BUILDDIR}/2019-02-22/reldir"
	genfile 1 "${BUILDDIR}/2019-02-22/reldir/bsd.rd"
	genfile 1 "${BUILDDIR}/2019-02-22/reldir/base66.tgz"

	cat <<-EOF >$TMP1
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

	report -M -r "$REPORT" -s "${LOGDIR}/stages"

	assert_file "$TMP1" "$REPORT"
fi

if testcase "failure"; then
	mkdir "$LOGDIR"
	echo "cvs log" >"${LOGDIR}/cvs.log"
	cat <<-EOF >$STAGES
	stage="1" name="env" exit="0" duration="1" log="${LOGDIR}/env.log" user="root" time="0"
	stage="2" name="cvs" exit="1" duration="10" log="${LOGDIR}/cvs.log" user="root" time="0"
	EOF
	cat <<-EOF >$TMP1
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

	report -M -r "$REPORT" -s "$STAGES"

	assert_file "$TMP1" "$REPORT"
fi

if testcase "missing stages"; then
	report -M -r "$REPORT" -s "$STAGES"
fi
