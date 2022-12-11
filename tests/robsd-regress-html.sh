setup() {
	mkdir "${TSHDIR}/html"
	{
		echo "${TSHDIR}/amd64/2022-10-25" 1666659600 0
		echo "${TSHDIR}/amd64/2022-10-24" 1666573200 1
		echo "${TSHDIR}/arm64/2022-10-25" 1666659600 0
		echo "${TSHDIR}/arm64/2022-10-24" 1666573200 1
	} | while read -r _dir _time _exit; do
		mkdir -p "$_dir"
		printf 'comment\n' >"${_dir}/comment"
		printf 'dmesg\n' >"${_dir}/dmesg"
		printf 'tags\n' >"${_dir}/tags"

		_marker="$(printf '===> subdir\n==== test ====')"
		_xtrace="+ x"
		printf '%s\n%s\nPASSED\n%s\n' "$_xtrace" "$_marker" "$_xtrace" >"${_dir}/pass.log"
		printf '%s\nSKIPPED\n' "$_marker" >"${_dir}/skip.log"
		printf '%s\nFAILED\n' "$_marker" >"${_dir}/fail-always.log"
		printf '%s\nFAILED\n' "$_marker" >"${_dir}/fail-once.log"
		printf '%s\nSKIPPED\n%s\nEXPECTED_FAIL\n' \
			"$_marker" "$_marker" >"${_dir}/xfail.log"

		{
			step_serialize -s 1 -n test/pass -l pass.log -t "$_time"
			step_serialize -H -s 2 -n test/skip -l skip.log -t "$_time"
			step_serialize -H -s 3 -n test/fail/once -e "$_exit" -l fail-once.log -t "$_time"
			step_serialize -H -s 4 -n test/fail/always -e 1 -l fail-always.log -t "$_time"
			step_serialize -H -s 4 -n test/xfail -l xfail.log -t "$_time"
		} >"$(step_path "$_dir")"
	done

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

# xpath xpath path
xpath() {
	local _xpath
	local _path
	local _xmllint

	_xpath="$1"; : "${_xpath:?}"
	_path="$2"; : "${_path:?}"

	_xmllint="$(which xmllint 2>/dev/null || echo /usr/local/bin/xmllint)"
	"$_xmllint" --html --xpath "$_xpath" "$_path" 2>/dev/null |
	grep -v -e '^[[:space:]]*$' -e '<' |
	xargs -r printf '%s\n'
}

if testcase -t xmllint "basic"; then
	robsd_regress_html -- -o "${TSHDIR}/html" \
		"amd64:${TSHDIR}/amd64" "arm64:${TSHDIR}/arm64"

	xpath '//th[@class="rate"]/text()' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" "dates" <<-EOF
	80%
	80%
	60%
	60%
	EOF

	xpath '//th[@class="date"]/text()' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" "dates" <<-EOF
	2022-10-25
	2022-10-25
	2022-10-24
	2022-10-24
	EOF

	xpath '//th[@class="arch"]/a/text()' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" "arches" <<-EOF
	amd64
	arm64
	amd64
	arm64
	EOF

	xpath '//a[@class="suite" or @class="status"]' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" "test suites" <<-EOF
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

	for _dir in \
		"${TSHDIR}/html/amd64/2022-10-25" \
		"${TSHDIR}/html/amd64/2022-10-24" \
		"${TSHDIR}/html/arm64/2022-10-25" \
		"${TSHDIR}/html/arm64/2022-10-24"
	do
		assert_file - "${_dir}/comment" <<-EOF
		comment
		EOF

		assert_file - "${_dir}/dmesg" <<-EOF
		dmesg
		EOF

		assert_file - "${_dir}/pass.log" <<-EOF
		===> subdir
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
		SKIPPED

		==== test ====
		EXPECTED_FAIL
		EOF
	done
fi

if testcase -t xmllint "changelog"; then
	printf 'cvs\n' >"${TSHDIR}/amd64/2022-10-25/tags"

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

if testcase -t xmllint "patches"; then
	printf 'cvs\n' >"${TSHDIR}/amd64/2022-10-25/tags"
	printf 'src.diff.1\n' >"${TSHDIR}/amd64/2022-10-25/src.diff.1"
	printf 'src.diff.2\n' >"${TSHDIR}/amd64/2022-10-25/src.diff.2"

	robsd_regress_html -- -o "${TSHDIR}/html" "amd64:${TSHDIR}/amd64"

	xpath '//th[@class="patch"]/a/text()' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	patches
	EOF
	xpath '//th[@class="patch"]/text()' "${TSHDIR}/html/index.html" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	n/a
	EOF
	assert_file - "${TSHDIR}/html/amd64/2022-10-25/diff/src.diff.1" <<-EOF
	src.diff.1
	EOF
	assert_file - "${TSHDIR}/html/amd64/2022-10-25/diff/src.diff.2" <<-EOF
	src.diff.2
	EOF
fi

if testcase "dmesg missing"; then
	rm "${TSHDIR}/amd64/2022-10-25/dmesg"

	robsd_regress_html - -- -o "${TSHDIR}/html" "amd64:${TSHDIR}/amd64" <<-EOF
	robsd-regress-html: open: ${TSHDIR}/amd64/2022-10-25/dmesg: No such file or directory
	EOF
fi

if testcase "comment missing"; then
	rm "${TSHDIR}/amd64/2022-10-25/comment"

	robsd_regress_html - -- -o "${TSHDIR}/html" "amd64:${TSHDIR}/amd64" <<-EOF
	robsd-regress-html: open: ${TSHDIR}/amd64/2022-10-25/comment: No such file or directory
	EOF
fi

if testcase "invalid: steps empty"; then
	: >"$(step_path "${TSHDIR}/amd64/2022-10-25")"

	robsd_regress_html -e - -- -o "${TSHDIR}/html" "amd64:${TSHDIR}/amd64" <<-EOF
	robsd-regress-html: ${TSHDIR}/amd64/2022-10-25/step.csv: no steps found
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
