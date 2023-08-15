_builddir="${TSHDIR}/2023-08-13.1"

setup() {
	mkdir "${TSHDIR}/.conf"

	robsd_config - <<-EOF
	robsddir "$TSHDIR"
	EOF
	mv "$ROBSDCONF" "${TSHDIR}/.conf/robsd.conf"

	robsd_config -C - <<-EOF
	robsddir "$TSHDIR"
	EOF
	mv "$ROBSDCONF" "${TSHDIR}/.conf/robsd-cross.conf"

	robsd_config -P - <<-EOF
	robsddir "$TSHDIR"
	ports { "devel/robsd" }
	EOF
	mv "$ROBSDCONF" "${TSHDIR}/.conf/robsd-ports.conf"

	robsd_config -R - <<-EOF
	robsddir "$TSHDIR"
	regress "test/pass"
	regress "test/fail/one"
	regress "test/fail/two"
	regress "test/quiet" quiet
	regress "test/skip"
	EOF
	mv "$ROBSDCONF" "${TSHDIR}/.conf/robsd-regress.conf"

	mkdir -p "${_builddir}/rel" "${_builddir}/tmp"
}

# robsd_report -m mode [-e] [-] -- [robsd-step-argument ...]
robsd_report() {
	local _err0=0
	local _err1=0
	local _mode=""
	local _stdin="${TSHDIR}/stdin"
	local _stdout="${TSHDIR}/stdout"

	while [ $# -gt 0 ]; do
		case "$1" in
		-e)	_err0="1";;
		-m)	shift; _mode="$1";;
		-)	cat >"$_stdin";;
		*)	break;;
		esac
		shift
	done
	: "${_mode:?}"
	[ "${1:-}" = "--" ] && shift

	${EXEC:-} "$ROBSDREPORT" -m "$_mode" -C "${TSHDIR}/.conf/${_mode}.conf" "$@" \
		>"$_stdout" 2>&1 || _err1="$?"
	if [ "$_err0" -ne "$_err1" ]; then
		fail - "expected exit ${_err0}, got ${_err1}" <"$_stdout"
		return 0
	fi
	if [ -e "$_stdin" ]; then
		assert_file "$_stdin" "$_stdout"
	else
		cat "$_stdout"
	fi
}

# genfile [-s scalar] size path
#
# Generate a file located at path of the given size which defaults to being
# expressed in MB.
genfile() {
	local _m="$((1024 * 1024))"
	local _p
	local _s

	while [ $# -gt 0 ]; do
		case "$1" in
		-s)	shift; _m="$1";;
		*)	break;;
		esac
		shift
	done

	_s="$1"; : "${_s}"
	_p="$2"; : "${_p}"

	dd if=/dev/zero "of=${_p}" "bs=$((_s * _m))" count=1 status=none
}

# genlog nlines
genlog() {
	local _i=1
	local _n

	_n="$1"; : "${_n:?}"
	while [ "$_i" -le "$_n" ]; do
		echo "$_i"
		_i="$((_i + 1))"
	done
}

if testcase "robsd: basic"; then
	{
		step_serialize -s 1 -n ok -l ok.log

		step_serialize -H -s 2 -n error -e 1 -l error.log
		genlog 20 >"${_builddir}/error.log"

		step_serialize -H -s 3 -n end -d 3661 -a 70
	} >"$(step_path "$_builddir")"
	printf 'comment\n\n' >"${_builddir}/comment"
	printf 'foo bar\n' >"${_builddir}/tags"

	robsd_report -m robsd - -- "$_builddir" <<-EOF
	Subject: robsd: $(hostname -s): ok

	> comment
	comment

	> stats
	Status: ok
	Duration: 01:01:01 (+00:01:10)
	Build: ${_builddir}
	Tags: foo bar

	> error
	Exit: 1
	Duration: 00:00:01
	Log: error.log

	11
	12
	13
	14
	15
	16
	17
	18
	19
	20
	EOF
fi

if testcase "robsd: cvs"; then
	{
		step_serialize -s 1 -n cvs -l cvs.log
		printf 'src up\n' >"${_builddir}/tmp/cvs-src-up.log"
		printf 'src ci\n' >"${_builddir}/tmp/cvs-src-ci.log"
		printf '' >"${_builddir}/tmp/cvs-xenocara-up.log"
		printf '' >"${_builddir}/tmp/cvs-xenocara-ci.log"
		printf 'ports up\n' >"${_builddir}/tmp/cvs-ports-up.log"
		printf 'ports ci\n' >"${_builddir}/tmp/cvs-ports-ci.log"

		step_serialize -H -s 2 -n end
	} >"$(step_path "$_builddir")"

	robsd_report -m robsd -- "$_builddir" | sed -n -e '/^> cvs/,$p' >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	> cvs
	Exit: 0
	Duration: 00:00:01
	Log: cvs.log

	src up

	src ci
	EOF
fi

if testcase "robsd: checkflist empty"; then
	{
		step_serialize -s 1 -n checkflist -l checkflist.log
		printf '+ one\n+ two\n' >"${_builddir}/checkflist.log"
	} >"$(step_path "$_builddir")"

	robsd_report -m robsd -- "$_builddir" | sed -n -e '/^> checkflist/,$p' >"$TMP1"
	assert_file /dev/null "$TMP1"
fi

if testcase "robsd: checkflist not empty"; then
	{
		step_serialize -s 1 -n checkflist -l checkflist.log
		printf '+ one\n+ two\nhello\n' >"${_builddir}/checkflist.log"
	} >"$(step_path "$_builddir")"

	robsd_report -m robsd -- "$_builddir" | sed -n -e '/^> checkflist/,$p' >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	> checkflist
	Exit: 0
	Duration: 00:00:01
	Log: checkflist.log

	+ one
	+ two
	hello
	EOF
fi

if testcase "robsd: skip"; then
	{
		step_serialize -s 1 -n cvs -i 1
	} >"$(step_path "$_builddir")"

	robsd_report -m robsd -- "$_builddir" | sed -n -e '/^> stats/,$p' >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	> stats
	Status: ok
	Duration: 00:00:00
	Build: ${_builddir}
	EOF
fi

if testcase "robsd: failure"; then
	{
		step_serialize -s 1 -n ok -l ok.log -d 10
		step_serialize -H -s 2 -n skip -i 1 -d 10
		step_serialize -H -s 3 -n error -e 1 -l error.log -d 10
		touch "${_builddir}/error.log"
	} >"$(step_path "$_builddir")"

	robsd_report -m robsd -- "$_builddir" | sed -n -e '/^> stats/,/^$/p' >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	> stats
	Status: failed in error
	Duration: 00:00:20
	Build: ${_builddir}

	EOF
fi

if testcase "robsd: sizes"; then
	_prev_builddir="${TSHDIR}/2023-08-12.1"
	mkdir -p "${_prev_builddir}/rel"
	genfile 2 "${_prev_builddir}/rel/grow"
	genfile 2 "${_prev_builddir}/rel/shrink"
	genfile 2 "${_prev_builddir}/rel/same"
	genfile 1 "${_prev_builddir}/rel/src.diff.1"
	genfile -s 1024 1 "${_prev_builddir}/rel/bsd.rd"

	{
		step_serialize -s 1 -n end
	} >"$(step_path "$_builddir")"
	genfile 3 "${_builddir}/rel/grow"
	genfile 1 "${_builddir}/rel/shrink"
	genfile 2 "${_builddir}/rel/same"
	genfile 4 "${_builddir}/rel/src.diff.1"
	genfile -s 1024 3 "${_builddir}/rel/bsd.rd"

	robsd_report -m robsd -- "$_builddir" | sed -n -e '/^> stats/,/^$/p' >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	> stats
	Status: ok
	Duration: 00:00:01
	Build: ${_builddir}
	Size: bsd.rd 3.0K (+2.0K)
	Size: grow 3.0M (+1.0M)
	Size: shrink 1.0M (-1.0M)
	EOF
fi

if testcase "robsd-cross: basic"; then
	{
		step_serialize -s 1 -n ok -l ok.log
		step_serialize -H -s 2 -n end
	} >"$(step_path "$_builddir")"
	echo arm64 >"${_builddir}/target"

	_machine="$(machine 2>/dev/null || arch)"
	robsd_report -m robsd-cross - -- "$_builddir" <<-EOF
	Subject: robsd-cross: $(hostname -s): ${_machine}.arm64: ok

	> stats
	Status: ok
	Duration: 00:00:01
	Build: ${_builddir}
	EOF
fi

if testcase "robsd-ports: basic"; then
	{
		step_serialize -s 1 -n cvs -l cvs.log
		printf 'ports up' >"${_builddir}/tmp/cvs-ports-up.log"
		printf 'ports ci' >"${_builddir}/tmp/cvs-ports-ci.log"

		step_serialize -H -s 2 -n dpb -l dpb.log
		printf 'diff' >"${_builddir}/tmp/packages.diff"

		step_serialize -H -s 3 -n end
	} >"$(step_path "$_builddir")"

	robsd_report -m robsd-ports - -- "$_builddir" <<-EOF
	Subject: robsd-ports: $(hostname -s): ok

	> stats
	Status: ok
	Duration: 00:00:01
	Build: ${_builddir}

	> cvs
	Exit: 0
	Duration: 00:00:01
	Log: cvs.log

	ports up

	ports ci

	> dpb
	Exit: 0
	Duration: 00:00:01
	Log: dpb.log

	diff
	EOF
fi

if testcase "robsd-ports: dpb failure"; then
	{
		step_serialize -s 1 -n dpb -e 1 -l dpb.log
		printf 'dpb failure\n' >"${_builddir}/dpb.log"
	} >"$(step_path "$_builddir")"

	robsd_report -m robsd-ports - -- "$_builddir" <<-EOF
	Subject: robsd-ports: $(hostname -s): failed in dpb

	> stats
	Status: failed in dpb
	Duration: 00:00:01
	Build: ${_builddir}

	> dpb
	Exit: 1
	Duration: 00:00:01
	Log: dpb.log

	dpb failure
	EOF
fi

if testcase "robsd-regress: basic"; then
	{
		step_serialize -s 1 -n test/pass -l pass.log
		printf '==== test ====\n' >"${_builddir}/pass.log"

		step_serialize -H -s 2 -n test/fail/one -e 1 -l fail-one.log
		printf 'discard\n==== test ====\nFAILED\n' >"${_builddir}/fail-one.log"

		step_serialize -H -s 3 -n test/fail/two -e 1 -l fail-two.log
		printf 'discard\n==== test ====\nFAILED\n' >"${_builddir}/fail-two.log"

		step_serialize -H -s 4 -n test/quiet -l quiet.log
		printf '==== test ====\nSKIPPED\n' >"${_builddir}/quiet.log"

		step_serialize -H -s 5 -n test/skip -l skip.log
		printf '==== test ====\nSKIPPED\n' >"${_builddir}/skip.log"

		step_serialize -H -s 6 -n end
	} >"$(step_path "$_builddir")"

	robsd_report -m robsd-regress - -- "$_builddir" <<-EOF
	Subject: robsd-regress: $(hostname -s): 2 failures

	> stats
	Status: 2 failures
	Duration: 00:00:01
	Build: ${_builddir}

	> test/fail/one
	Exit: 1
	Duration: 00:00:01
	Log: fail-one.log

	==== test ====
	FAILED

	> test/fail/two
	Exit: 1
	Duration: 00:00:01
	Log: fail-two.log

	==== test ====
	FAILED

	> test/skip
	Exit: 0
	Duration: 00:00:01
	Log: skip.log

	==== test ====
	SKIPPED
	EOF
fi

if testcase "robsd-regress: ok"; then
	{
		step_serialize -s 1 -n test/pass -l pass.log
		: >"${_builddir}/pass.log"
	} >"$(step_path "$_builddir")"

	robsd_report -m robsd-regress -- "$_builddir" | sed -n -e '/^Subject/p' >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	Subject: robsd-regress: $(hostname -s): ok
	EOF
fi

if testcase "robsd-regress: one failure"; then
	{
		step_serialize -s 1 -n test/fail/one -e 1 -l fail-one.log
		: >"${_builddir}/fail-one.log"
	} >"$(step_path "$_builddir")"

	robsd_report -m robsd-regress -- "$_builddir" | sed -n -e '/^Subject/p' >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	Subject: robsd-regress: $(hostname -s): 1 failure
	EOF
fi

if testcase "robsd-regress: failure in non-regress step"; then
	{
		step_serialize -s 1 -n env -e 1 -l env.log
		printf 'env failure\n' >"${_builddir}/env.log"
	} >"$(step_path "$_builddir")"

	robsd_report -m robsd -- "$_builddir" | sed -n -e '/^> env/,$p' >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	> env
	Exit: 1
	Duration: 00:00:01
	Log: env.log

	env failure
	EOF
fi

if testcase "step log one line"; then
	{
		step_serialize -s 1 -n error -e 1 -l error.log
		printf 'a\n' >"${_builddir}/error.log"
	} >"$(step_path "$_builddir")"

	robsd_report -m robsd -- "$_builddir" | sed -n -e '/^> error/,$p' >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	> error
	Exit: 1
	Duration: 00:00:01
	Log: error.log

	a
	EOF
fi

if testcase "step log few lines"; then
	{
		step_serialize -s 1 -n error -e 1 -l error.log
		printf 'a\nb\n' >"${_builddir}/error.log"
	} >"$(step_path "$_builddir")"

	robsd_report -m robsd -- "$_builddir" | sed -n -e '/^> error/,$p' >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	> error
	Exit: 1
	Duration: 00:00:01
	Log: error.log

	a
	b
	EOF
fi

if testcase "step log no trailing new line"; then
	{
		step_serialize -s 1 -n error -e 1 -l error.log
		printf 'a' >"${_builddir}/error.log"
	} >"$(step_path "$_builddir")"

	robsd_report -m robsd -- "$_builddir" | sed -n -e '/^> error/,$p' >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	> error
	Exit: 1
	Duration: 00:00:01
	Log: error.log

	a
	EOF
fi

if testcase "step log empty"; then
	{
		step_serialize -s 1 -n error -e 1 -l error.log
		touch "${_builddir}/error.log"
	} >"$(step_path "$_builddir")"

	robsd_report -m robsd -- "$_builddir" | sed -n -e '/^> error/,$p' >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	> error
	Exit: 1
	Duration: 00:00:01
	Log: error.log

	EOF
fi

if testcase "error: missing mode"; then
	if ${EXEC:-} "$ROBSDREPORT" >"$TMP1" 2>&1; then
		fail - "expected exit non-zero" <"$TMP1"
	fi
	if ! grep -q usage "$TMP1"; then
		fail - "expected usage" <"$TMP1"
	fi
fi

if testcase "error: unknown mode"; then
	if ${EXEC:-} "$ROBSDREPORT" -m nein /var/empty >"$TMP1" 2>&1; then
		fail - "expected exit non-zero" <"$TMP1"
	fi
	if ! grep -q 'unknown mode' "$TMP1"; then
		fail - "expected unknown mode" <"$TMP1"
	fi
fi

if testcase "error: config invalid"; then
	chmod u-r "${TSHDIR}/.conf/robsd.conf"

	robsd_report -e -m robsd - -- "$_builddir" <<-EOF
	robsd-report: ${TSHDIR}/.conf/robsd.conf: Permission denied
	EOF
fi

if testcase "error: comment invalid"; then
	{
		step_serialize -s 1 -n end
	} >"$(step_path "$_builddir")"
	printf 'comment\n\n' >"${_builddir}/comment"
	chmod u-r "${_builddir}/comment"

	robsd_report -e -m robsd - -- "$_builddir" <<-EOF
	robsd-report: ${_builddir}/comment: Permission denied
	EOF
fi

if testcase "error: step.cvs invalid"; then
	{
		step_serialize -s 1 -n end
	} >"$(step_path "$_builddir")"
	chmod u-r "$(step_path "$_builddir")"

	robsd_report -e -m robsd - -- "$_builddir" <<-EOF
	robsd-report: $(step_path "${_builddir}"): Permission denied
	EOF
fi
