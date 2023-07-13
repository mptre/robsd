setup() {
	mkdir "${TSHDIR}/html"
}

# mkbuilddir [-t tags] path
mkbuilddir() {
	local _tags="tags"

	while [ $# -gt 0 ]; do
		case "$1" in
		-t)	shift; _tags="$1";;
		*)	break;;
		esac
		shift
	done

	_path="$1"; : "${_path:?}"
	mkdir -p "$_path"
	echo comment >"${_path}/comment"
	echo dmesg >"${_path}/dmesg"
	echo "$_tags" >"${_path}/tags"
}

# robsd_regress_html [-e] [-] -- [robsd-regress-html-argument ...]
robsd_regress_html() {
	local _err0=0
	local _err1=0
	local _stdin="${TSHDIR}/stdin"
	local _stdout="${TSHDIR}/stdout"

	while [ $# -gt 0 ]; do
		case "$1" in
		-e)	_err0="1";;
		-)	cat >"$_stdin";;
		*)	break;;
		esac
		shift
	done
	[ "${1:-}" = "--" ] && shift

	${EXEC:-} "$ROBSDREGRESSHTML" "$@" >"$_stdout" 2>&1 || _err1="$?"
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

# step_log outcome
step_log() {
	local _outcome

	_outcome="$1"; : "${_outcome:?}"
	printf 'junk\n\n'
	printf '==== test ====\n'
	printf '%s\n' "$_outcome"
}

# xpath xpath path
xpath() {
	local _xpath
	local _path

	_xpath="$1"; : "${_xpath:?}"
	_path="$2"; : "${_path:?}"

	"$_xmllint" --html --xpath "$_xpath" "$_path" 2>/dev/null |
	grep -v -e '^[[:space:]]*$' -e '<' |
	xargs -r printf '%s\n'
}

_2022_10_25=1666659600
_2022_10_24=$((_2022_10_25 - 86400))
_2022_10_23=$((_2022_10_24 - 86400))

# xmllint is required to run these tests.
_xmllint="$(which xmllint 2>/dev/null || echo /usr/local/bin/xmllint)"
ls "$_xmllint" >/dev/null

if testcase "basic"; then
	_buildir="${TSHDIR}/amd64/2022-10-25.1"
	_time="$_2022_10_25"
	mkbuilddir "$_buildir"
	{
		step_serialize -s 1 -n test/pass -l pass.log -t "$_time"
		step_log PASSED >"${_buildir}/pass.log"

		step_serialize -H -s 2 -n test/skip -l skip.log -t "$_time"
		step_log SKIPPED >"${_buildir}/skip.log"

		step_serialize -H -s 3 -n test/fail/once -l fail-once.log -t "$_time"
		step_log PASSED >"${_buildir}/fail-once.log"

		step_serialize -H -s 4 -n test/fail/always -l fail-always.log -t "$_time" -e 1
		step_log FAILED >"${_buildir}/fail-always.log"

		step_serialize -H -s 5 -n test/xfail -l xfail.log -t "$_time"
		step_log EXPECTED_FAIL >"${_buildir}/xfail.log"

		step_serialize -H -s 6 -n end -d 1800 -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	_buildir="${TSHDIR}/amd64/2022-10-24.1"
	_time="$_2022_10_24"
	mkbuilddir "$_buildir"
	{
		step_serialize -s 1 -n test/pass -l pass.log -t "$_time"
		step_log PASSED >"${_buildir}/pass.log"

		step_serialize -H -s 2 -n test/skip -l skip.log -t "$_time"
		step_log SKIPPED >"${_buildir}/skip.log"

		step_serialize -H -s 3 -n test/fail/once -l fail-once.log -t "$_time" -e 1
		step_log FAILED >"${_buildir}/fail-once.log"

		step_serialize -H -s 4 -n test/fail/always -l fail-always.log -t "$_time" -e 1
		step_log FAILED >"${_buildir}/fail-always.log"

		step_serialize -H -s 5 -n test/xfail -l xfail.log -t "$_time"
		step_log EXPECTED_FAIL >"${_buildir}/xfail.log"

		step_serialize -H -s 6 -n end -t "$((_time + 3600))" -d 3660
	} >"$(step_path "$_buildir")"

	_buildir="${TSHDIR}/arm64/2022-10-25.1"
	_time="$_2022_10_25"
	mkbuilddir "$_buildir"
	{
		step_serialize -s 1 -n test/pass -l pass.log -t "$_time"
		step_log PASSED >"${_buildir}/pass.log"

		step_serialize -H -s 2 -n test/skip -l skip.log -t "$_time"
		step_log SKIPPED >"${_buildir}/skip.log"

		step_serialize -H -s 3 -n test/fail/once -l fail-once.log -t "$_time"
		step_log PASSED >"${_buildir}/fail-once.log"

		step_serialize -H -s 4 -n test/fail/always -l fail-always.log -t "$_time" -e 1
		step_log FAILED >"${_buildir}/fail-always.log"

		step_serialize -H -s 5 -n test/xfail -l xfail.log -t "$_time"
		step_log EXPECTED_FAIL >"${_buildir}/xfail.log"

		step_serialize -H -s 6 -n end -t "$((_time + 3600))" -d 3660
	} >"$(step_path "$_buildir")"

	_buildir="${TSHDIR}/arm64/2022-10-24.1"
	_time="$_2022_10_24"
	mkbuilddir "$_buildir"
	{
		step_serialize -s 1 -n test/pass -l pass.log -t "$_time"
		step_log PASSED >"${_buildir}/pass.log"

		step_serialize -H -s 2 -n test/skip -l skip.log -t "$_time"
		step_log SKIPPED >"${_buildir}/skip.log"

		step_serialize -H -s 3 -n test/fail/once -l fail-once.log -t "$_time" -e 1
		step_log FAILED >"${_buildir}/fail-once.log"

		step_serialize -H -s 4 -n test/fail/always -l fail-always.log -t "$_time" -e 1
		step_log FAILED >"${_buildir}/fail-always.log"

		step_serialize -H -s 5 -n test/xfail -l xfail.log -t "$_time"
		step_log EXPECTED_FAIL >"${_buildir}/xfail.log"

		step_serialize -H -s 6 -n end -t "$((_time + 3600))" -d 1800
	} >"$(step_path "$_buildir")"

	robsd_regress_html -- -o "${TSHDIR}/html" \
		"amd64:${TSHDIR}/amd64" "arm64:${TSHDIR}/arm64"

	xpath '//th[@class="pass"]/text()' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" "pass" <<-EOF
	80%
	80%
	60%
	60%
	EOF

	xpath '//th[@class="date"]/text()' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" "date" <<-EOF
	2022-10-25.1
	2022-10-25.1
	2022-10-24.1
	2022-10-24.1
	EOF

	xpath '//th[@class="dura"]/text()' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" "duration" <<-EOF
	0h30m
	1h1m
	1h1m
	0h30m
	EOF

	xpath '//th[@class="arch"]/a/text()' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" "arches" <<-EOF
	amd64
	arm64
	amd64
	arm64
	EOF

	xpath '//a[@class="suite" or @class="status"]' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" "suites" <<-EOF
	test/fail/always
	FAIL
	FAIL
	FAIL
	FAIL
	test/fail/once
	PASS
	PASS
	FAIL
	FAIL
	test/pass
	PASS
	PASS
	PASS
	PASS
	test/skip
	SKIP
	SKIP
	SKIP
	SKIP
	test/xfail
	XFAIL
	XFAIL
	XFAIL
	XFAIL
	EOF

	for _d in \
		amd64/2022-10-25.1 amd64/2022-10-24.1 \
		arm64/2022-10-25.1 arm64/2022-10-24.1
	do
		_dir="${TSHDIR}/html/${_d}"

		assert_file - "${_dir}/comment" <<-EOF
		comment
		EOF

		assert_file - "${_dir}/dmesg" <<-EOF
		dmesg
		EOF

		assert_file - "${_dir}/pass.log" <<-EOF
		junk

		==== test ====
		PASSED
		EOF

		assert_file - "${_dir}/skip.log" <<-EOF
		==== test ====
		SKIPPED
		EOF

		assert_file - "${_dir}/fail-always.log" <<-EOF
		==== test ====
		FAILED
		EOF

		assert_file - "${_dir}/xfail.log" <<-EOF
		==== test ====
		EXPECTED_FAIL
		EOF
	done
fi

if testcase "changelog"; then
	_buildir="${TSHDIR}/amd64/2022-10-25.1"
	_time="$_2022_10_25"
	mkbuilddir -t cvs "$_buildir"
	{
		step_serialize -s 1 -n test/pass -l pass.log -t "$_time"
		step_log PASSED >"${_buildir}/pass.log"

		step_serialize -H -s 2 -n end -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	_buildir="${TSHDIR}/amd64/2022-10-24.1"
	_time="$_2022_10_24"
	mkbuilddir "$_buildir"
	{
		step_serialize -s 1 -n test/pass -l pass.log -t "$_time"
		step_log PASSED >"${_buildir}/pass.log"

		step_serialize -H -s 2 -n end -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	robsd_regress_html -- -o "${TSHDIR}/html" "amd64:${TSHDIR}/amd64"

	xpath '//th[@class="cvs"]/a/text()' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	cvs
	EOF

	xpath '//th[@class="cvs"]/text()' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	n/a
	EOF
fi

if testcase "patches"; then
	_buildir="${TSHDIR}/amd64/2022-10-25.1"
	_time="$_2022_10_25"
	mkbuilddir -t cvs "$_buildir"
	printf 'src.diff.1\n' >"${_buildir}/src.diff.1"
	printf 'src.diff.2\n' >"${_buildir}/src.diff.2"
	{
		step_serialize -s 1 -n test/pass -l pass.log -t "$_time"
		step_log PASSED >"${_buildir}/pass.log"

		step_serialize -H -s 2 -n end -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	_buildir="${TSHDIR}/amd64/2022-10-24.1"
	_time="$_2022_10_24"
	mkbuilddir "$_buildir"
	{
		step_serialize -s 1 -n test/pass -l pass.log -t "$_time"
		step_log PASSED >"${_buildir}/pass.log"

		step_serialize -H -s 2 -n end -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	robsd_regress_html -- -o "${TSHDIR}/html" "amd64:${TSHDIR}/amd64"

	xpath '//th[@class="patch"]/a/text()' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	patches
	EOF

	xpath '//th[@class="patch"]/text()' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	n/a
	EOF

	assert_file - "${TSHDIR}/html/amd64/2022-10-25.1/diff/src.diff.1" <<-EOF
	src.diff.1
	EOF

	assert_file - "${TSHDIR}/html/amd64/2022-10-25.1/diff/src.diff.2" <<-EOF
	src.diff.2
	EOF
fi

if testcase "multiple invocations per day"; then
	_buildir="${TSHDIR}/amd64/2022-10-25.2"
	_time="$((_2022_10_25 + 3600))"
	mkbuilddir -t cvs "$_buildir"
	{
		step_serialize -s 1 -n test/pass -l pass.log -t "$_time"
		step_log PASSED >"${_buildir}/pass.log"

		step_serialize -H -s 2 -n end -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	_buildir="${TSHDIR}/amd64/2022-10-25.1"
	_time="$_2022_10_25"
	mkbuilddir -t cvs "$_buildir"
	{
		step_serialize -s 1 -n test/pass -l pass.log -t "$_time"
		step_log PASSED >"${_buildir}/pass.log"

		step_serialize -H -s 2 -n end -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	robsd_regress_html - -- -o "${TSHDIR}/html" "amd64:${TSHDIR}/amd64" </dev/null

	xpath '//th[@class="date"]/text()' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	2022-10-25.2
	2022-10-25.1
	EOF

	xpath '//td[@class="PASS"]/a/@href' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	href=amd64/2022-10-25.2/pass.log
	href=amd64/2022-10-25.1/pass.log
	EOF
fi

if testcase "non-regress suites"; then
	_buildir="${TSHDIR}/amd64/2022-10-25.1"
	_time="$_2022_10_25"
	mkbuilddir "$_buildir"
	{
		step_serialize -s 1 -n test/first -l first.log -t "$_time"
		step_log PASSED >"${_buildir}/first.log"

		step_serialize -H -s 2 -n ../b -l b.log -t "$_time"
		step_log PASSED >"${_buildir}/b.log"

		step_serialize -H -s 3 -n ../a -l b.log -t "$_time"
		step_log PASSED >"${_buildir}/a.log"

		step_serialize -H -s 4 -n end -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	robsd_regress_html - -- -o "${TSHDIR}/html" "amd64:${TSHDIR}/amd64" </dev/null

	xpath '//a[@class="suite"]/text()' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	test/first
	../a
	../b
	EOF
fi


if testcase "missing runs"; then
	_buildir="${TSHDIR}/amd64/2022-10-25.1"
	_time="$_2022_10_25"
	mkbuilddir "$_buildir"
	{
		step_serialize -s 1 -n test/always -l always.log -t "$_time"
		step_log PASSED >"${_buildir}/always.log"

		step_serialize -H -s 2 -n end -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	_buildir="${TSHDIR}/amd64/2022-10-24.1"
	_time="$_2022_10_24"
	mkbuilddir "$_buildir"
	{
		step_serialize -s 1 -n test/always -l always.log -t "$_time"
		step_log PASSED >"${_buildir}/always.log"

		step_serialize -H -s 2 -n test/once -l once.log -t "$_time"
		step_log SKIPPED >"${_buildir}/once.log"

		step_serialize -H -s 2 -n end -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	_buildir="${TSHDIR}/amd64/2022-10-23.1"
	_time="$_2022_10_23"
	mkbuilddir "$_buildir"
	{
		step_serialize -s 1 -n test/always -l always.log -t "$_time"
		step_log PASSED >"${_buildir}/always.log"

		step_serialize -H -s 2 -n end -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	robsd_regress_html -- -o "${TSHDIR}/html" "macppc:${TSHDIR}/amd64"

	xpath '//a[@class="suite" or @class="status"]' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	test/always
	PASS
	PASS
	PASS
	test/once
	SKIP
	EOF
fi

if testcase "dmesg missing"; then
	_buildir="${TSHDIR}/amd64/2022-10-25.1"
	_time="$_2022_10_25"
	mkbuilddir "$_buildir"
	rm "${_buildir}/dmesg"
	{
		step_serialize -s 1 -n test/pass -l pass.log -t "$_time"
		step_log PASSED >"${_buildir}/pass.log"

		step_serialize -H -s 2 -n end -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	robsd_regress_html - -- -o "${TSHDIR}/html" "amd64:${TSHDIR}/amd64" <<-EOF
	robsd-regress-html: ${TSHDIR}/amd64/2022-10-25.1/dmesg: No such file or directory
	EOF
fi

if testcase "comment missing"; then
	_buildir="${TSHDIR}/amd64/2022-10-25.1"
	_time="$_2022_10_25"
	mkbuilddir "$_buildir"
	rm "${_buildir}/comment"
	{
		step_serialize -s 1 -n test/pass -l pass.log -t "$_time"
		step_log PASSED >"${_buildir}/pass.log"

		step_serialize -H -s 2 -n end -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	robsd_regress_html - -- -o "${TSHDIR}/html" "amd64:${TSHDIR}/amd64" <<-EOF
	robsd-regress-html: ${TSHDIR}/amd64/2022-10-25.1/comment: No such file or directory
	EOF
fi

if testcase "suites ordering"; then
	_buildir="${TSHDIR}/amd64/2022-10-25.1"
	_time="$_2022_10_25"
	mkbuilddir "$_buildir"
	{
		step_serialize -s 1 -n test/new -l new.log -t "$_time"
		step_log PASSED >"${_buildir}/new.log"

		step_serialize -H -s 2 -n test/pass -l pass.log -t "$_time"
		step_log PASSED >"${_buildir}/pass.log"

		step_serialize -H -s 3 -n end -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	_buildir="${TSHDIR}/amd64/2022-10-24.1"
	_time="$_2022_10_24"
	mkbuilddir "$_buildir"
	{
		step_serialize -s 1 -n test/pass -l pass.log -t "$_time"
		step_log PASSED >"${_buildir}/pass.log"

		step_serialize -H -s 2 -n end -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	robsd_regress_html -- -o "${TSHDIR}/html" "amd64:${TSHDIR}/amd64"

	xpath '//a[@class="suite"]' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" "suites" <<-EOF
	test/new
	test/pass
	EOF
fi

if testcase "unknown failure"; then
	_buildir="${TSHDIR}/amd64/2022-10-25.1"
	_time="$_2022_10_25"
	mkbuilddir "$_buildir"
	{
		step_serialize -s 1 -n test/fail -l fail.log -t "$_time" -e 1
		cat <<-'EOF' >"${_buildir}/fail.log"
		+ shell trace expected to be stripped
		something robsd-regress-log cannot interpret
		+ shell trace expected to be stripped
		EOF

		step_serialize -H -s 2 -n end -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	robsd_regress_html -- -o "${TSHDIR}/html" "amd64:${TSHDIR}/amd64"

	assert_file "${TSHDIR}/html/amd64/2022-10-25.1/fail.log" - <<-'EOF'
	something robsd-regress-log cannot interpret
	EOF
fi

if testcase "unexpected pass"; then
	_buildir="${TSHDIR}/amd64/2022-10-25.1"
	_time="$_2022_10_25"
	mkbuilddir "$_buildir"
	{
		step_serialize -s 1 -n test/xpass -l xpass.log -t "$_time" -e 1
		{
			step_log UNEXPECTED_PASS
			step_log FAILED
			step_log EXPECTED_FAIL
		} >"${_buildir}/xpass.log"

		step_serialize -H -s 2 -n test/fail -l fail.log -t "$_time" -e 1
		step_log FAILED >"${_buildir}/fail.log"

		step_serialize -H -s 3 -n test/pass -l pass.log -t "$_time"
		step_log PASSED >"${_buildir}/pass.log"

		step_serialize -H -s 4 -n end -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	robsd_regress_html -- -o "${TSHDIR}/html" "amd64:${TSHDIR}/amd64"

	xpath '//a[@class="suite" or @class="status"]' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	test/fail
	FAIL
	test/xpass
	XPASS
	test/pass
	PASS
	EOF

	assert_file - "${TSHDIR}/html/amd64/2022-10-25.1/xpass.log" <<-EOF
	==== test ====
	UNEXPECTED_PASS

	==== test ====
	FAILED

	==== test ====
	EXPECTED_FAIL
	EOF
fi

if testcase "invalid: steps empty"; then
	_buildir="${TSHDIR}/amd64/2022-10-25.1"
	_time="$_2022_10_25"
	mkbuilddir "$_buildir"
	: >"$(step_path "$_buildir")"

	robsd_regress_html -e - -- -o "${TSHDIR}/html" "amd64:${TSHDIR}/amd64" <<-EOF
	robsd-regress-html: ${TSHDIR}/amd64/2022-10-25.1/step.csv: no steps found
	EOF
fi

if testcase "invalid: end step missing"; then
	_buildir="${TSHDIR}/amd64/2022-10-25.1"
	_time="$_2022_10_25"
	mkbuilddir "$_buildir"
	{
		step_serialize -s 1 -n test/pass -l pass.log -t "$_time"
		step_log PASSED >"${_buildir}/pass.log"
	} >"$(step_path "$_buildir")"

	robsd_regress_html -e - -- -o "${TSHDIR}/html" "amd64:${TSHDIR}/amd64" <<-EOF
	robsd-regress-html: ${TSHDIR}/amd64/2022-10-25.1/step.csv: end step not found
	EOF
fi

if testcase "invalid: directory not found"; then
	robsd_regress_html -e - -- -o "$TSHDIR" "amd64:${TSHDIR}/nein" <<-EOF
	robsd-regress-html: opendir: ${TSHDIR}/nein: No such file or directory
	EOF
fi

if testcase "invalid: missing separator between arch and directory"; then
	robsd_regress_html -e - -- -o "$TSHDIR" amd64 <<-EOF
	robsd-regress-html: amd64: invalid argument
	EOF
fi

if testcase "invalid: missing output directory"; then
	robsd_regress_html -e >"$TMP1"
	if ! grep -q usage "$TMP1"; then
		fail - "expected usage" <"$TMP1"
	fi
fi

if testcase "invalid: missing log"; then
	_buildir="${TSHDIR}/amd64/2022-10-25.1"
	_time="$_2022_10_25"
	mkbuilddir "$_buildir"
	{
		step_serialize -s 1 -n test/nein -l nein.log -t "$_time"

		step_serialize -H -s 2 -n end -t "$((_time + 3600))"
	} >"$(step_path "$_buildir")"

	robsd_regress_html -e - -- -o "${TSHDIR}/html" "amd64:${TSHDIR}/amd64" <<-EOF
	robsd-regress-html: open: ${TSHDIR}/amd64/2022-10-25.1/nein.log: No such file or directory
	robsd-regress-html: open: ${TSHDIR}/amd64/2022-10-25.1/nein.log: No such file or directory
	robsd-regress-html: open: ${TSHDIR}/amd64/2022-10-25.1/nein.log: No such file or directory
	robsd-regress-html: open: ${TSHDIR}/amd64/2022-10-25.1/nein.log: No such file or directory
	robsd-regress-html: open: ${TSHDIR}/amd64/2022-10-25.1/nein.log: No such file or directory
	robsd-regress-html: ${TSHDIR}/amd64/2022-10-25.1/nein.log: failed to parse log
	EOF
fi
