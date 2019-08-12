LOGDIR="${WRKDIR}/logdir"
STAGES="${WRKDIR}/stages"
REPORT="${WRKDIR}/report"

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
	# Create stages for the previous release in order to report duration
	# delta(s).
	cat <<-EOF >${BUILDDIR}/2019-02-22/stages
	stage="2" name="cvs" exit="0" duration="298" log="/dev/null" user="root" time="0"
	EOF
	cat <<-EOF >$TMP1
	> comment:
	comment goes here

	> stats:
	Build: ${LOGDIR}
	Status: ok
	Duration: 01:00:00
	Size: bsd 0
	Size: bsd.mp 0
	Size: bsd.rd 0

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
	Build: ${LOGDIR}
	Status: failed in cvs
	Duration: 00:00:11
	Size: bsd 0
	Size: bsd.mp 0
	Size: bsd.rd 0

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
