. "${EXECDIR}/util-cross.sh"
. "${EXECDIR}/util-ports.sh"
. "${EXECDIR}/util-regress.sh"

BUILDDIR="${ROBSDDIR}/2019-02-23"
STEPS="$(step_path "$BUILDDIR")"
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
	step_serialize -n cvs -d 30 >"$(step_path "${ROBSDDIR}/2019-02-21")"

	# Create a previous release in order to report size deltas.
	build_init "${ROBSDDIR}/2019-02-22"
	step_serialize -n cvs -i 1 >"$(step_path "${ROBSDDIR}/2019-02-22")"
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
	{
		step_serialize -s 1 -n env -d 0
		step_serialize -s 2 -n cvs -d 60 -l cvs.log
		step_serialize -s 3 -n patch -d 0
		step_serialize -s 4 -n kernel -i 1
		step_serialize -s 5 -n end -d 3600
	} >"$(step_path "$BUILDDIR")"
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

	report -r "$ROBSDDIR" -b "$BUILDDIR"

	assert_file "$TMP1" "$REPORT"
fi

if testcase "failure"; then
	build_init "$BUILDDIR"
	echo "env log" >"${BUILDDIR}/env.log"
	echo "cvs log" >"${BUILDDIR}/cvs.log"
	{
		step_serialize -s 1 -n cvs -d 11 -l "${BUILDDIR}/cvs.log"
		step_serialize -s 2 -n env -d 10 -l "${BUILDDIR}/env.log" -e 1
		step_serialize -s 3 -n patch -i 1
	} >"$STEPS"
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

	report -r "$ROBSDDIR" -b "$BUILDDIR"

	assert_file "$TMP1" "$REPORT"
fi

if testcase "failure in skipped step"; then
	build_init "$BUILDDIR"
	echo "env log" >"${BUILDDIR}/env.log"
	step_serialize -s 1 -n env -e 1 -d 1 -l "${BUILDDIR}/env.log" >"$STEPS"
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

	report -r "$ROBSDDIR" -b "$BUILDDIR"

	assert_file "$TMP1" "$REPORT"
fi

if testcase "missing step"; then
	if report -r "$ROBSDDIR" -b "$BUILDDIR"; then
		fail "want exit 1, got 0"
	fi
fi

if testcase "regress"; then
	build_init "$BUILDDIR"
	cat <<-EOF >"${BUILDDIR}/skipped.log"
	==== t0 ====
	SKIPPED

	==== t1 ====
	DISABLED
	EOF
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
	cat <<-EOF >"${BUILDDIR}/error.log"
	cc -O2 -pipe  -Wall  -MD -MP  -c log.c
	error: unable to open output file 'log.o': 'Read-only file system'
	X-Fail: error
	X-Skip: skip
	EOF
	cat <<-EOF >"${BUILDDIR}/skipignore.log"
	===> test
	SKIPPED
	EOF
	cat <<-EOF >"${BUILDDIR}/disabled.log"
	==== t0 ====
	DISABLED
	EOF
	{
		step_serialize -s 1 -n skipped -d 10 -l "${BUILDDIR}/skipped.log"
		step_serialize -s 2 -n nein -e 1 -d 1 -l "${BUILDDIR}/nein.log"
		step_serialize -s 3 -n error -e 1 -d 1 -l "${BUILDDIR}/error.log"
		step_serialize -s 4 -n skipignore -d 1 -l "${BUILDDIR}/skipignore.log"
		step_serialize -s 5 -n disabled -d 10 -l "${BUILDDIR}/disabled.log"
		step_serialize -s 6 -n end -d 12
	} >"$STEPS"

	robsd_config -R - <<-EOF
	robsddir "$ROBSDDIR"
	regress "skipped"
	regress "nein"
	regress "error"
	regress "skipignore" quiet
	regress "disabled" quiet
	EOF
	(setmode "robsd-regress" && report -r "$ROBSDDIR" -b "$BUILDDIR")

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

	==== t0 ====
	SKIPPED

	==== t1 ====
	DISABLED

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
	Fail: error
	Skip: skip

	cc -O2 -pipe  -Wall  -MD -MP  -c log.c
	error: unable to open output file 'log.o': 'Read-only file system'
	X-Fail: error
	X-Skip: skip
	EOF
fi

if testcase "ports"; then
	build_init "$BUILDDIR"
	step_serialize -n dpb -d 20 -l dpb.log >"$STEPS"
	robsd_config -P - <<-EOF
	robsddir "$ROBSDDIR"
	ports { "keep/quiet" }
	EOF

	# shellcheck disable=SC2034
	(PORTS="mail/mdsort"; setmode "robsd-ports";
	 report -r "$ROBSDDIR" -b "$BUILDDIR")

	assert_file - "$REPORT" <<-EOF
	Subject: robsd-ports: $(hostname -s): ok

	> stats:
	Status: ok
	Duration: 00:00:20
	Build: ${BUILDDIR}

	> dpb:
	Exit: 0
	Duration: 00:00:20
	Log: dpb.log
	EOF
fi

if testcase "ports failure"; then
	build_init "$BUILDDIR"
	step_serialize -n dpb -e 1 -d 20 >"$STEPS"
	robsd_config -P - <<-EOF
	robsddir "$ROBSDDIR"
	ports { "keep/quiet" }
	EOF

	# shellcheck disable=SC2034
	(PORTS="mail/mdsort"; setmode "robsd-ports";
	 report -r "$ROBSDDIR" -b "$BUILDDIR")

	assert_file - "$REPORT" <<-EOF
	Subject: robsd-ports: $(hostname -s): failed in dpb

	> stats:
	Status: failed in dpb
	Duration: 00:00:20
	Build: ${BUILDDIR}

	> dpb:
	Exit: 1
	Duration: 00:00:20
	Log: null
	EOF
fi
