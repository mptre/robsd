# robsd_regress_log [-] [-- robsd-regress-log-argument ...]
robsd_regress_log() {
	local _err0=0
	local _err1=0
	local _stdin=0
	local _stdout="${TSHDIR}/stdout"

	while [ $# -gt 0 ]; do
		case "$1" in
		-e)	_err0=$((_err0 + 1));;
		-)	_stdin=1;;
		*)	break;;
		esac
		shift
	done
	[ "${1:-}" = "--" ] && shift

	${EXEC:-} "$ROBSDREGRESSLOG" "$@" \
		>"$_stdout" 2>&1 || _err1="$?"
	if [ "$_err0" -ne "$_err1" ]; then
		fail - "expected exit ${_err0}, got ${_err1}" <"$_stdout"
		return 0
	fi
	if [ "$_stdin" -eq 1 ]; then
		assert_file - "$_stdout"
	else
		cat "$_stdout"
	fi
}

if testcase "skipped"; then
	cat <<-EOF >"$TMP1"
	cc   -o optionstest optionstest.o apps.o -lcrypto -lssl

	===> x509
	missing package p5-IO-Socket-SSL
	SKIPPED
	===> second
	SKIPPED
	EOF

	robsd_regress_log - -- -S "$TMP1" <<-EOF
	===> x509
	missing package p5-IO-Socket-SSL
	SKIPPED

	===> second
	SKIPPED
	EOF
fi

if testcase "skipped many lines"; then
	cat <<-EOF >"$TMP1"
	==== t-permit-1 ====
	t-permit-1

	==== t-run-keepenv-path ====
	All of directories we are allowed to use for temporary data
	(/home/src/regress/usr.bin/doas/obj /tmp)
	lie on nosuid filesystems, so we cannot run doas there.
	SKIPPED
	EOF

	robsd_regress_log - -- -S "$TMP1" <<-EOF
	==== t-run-keepenv-path ====
	All of directories we are allowed to use for temporary data
	(/home/src/regress/usr.bin/doas/obj /tmp)
	lie on nosuid filesystems, so we cannot run doas there.
	SKIPPED
	EOF
fi

if testcase "skipped no lines"; then
	cat <<-EOF >"$TMP1"
	==== test
	SKIPPED
	EOF

	robsd_regress_log - -- -S "$TMP1" <<-EOF
	==== test
	SKIPPED
	EOF
fi

if testcase "skipped early without marker"; then
	cat <<-EOF >"$TMP1"
	+ trace1
	package test is required for this regress
	SKIPPED
	+ trace2
	package test is required for this regress
	SKIPPED
	+ trace3
	EOF

	robsd_regress_log - -- -S "$TMP1" <<-EOF
	package test is required for this regress
	SKIPPED

	+ trace2
	package test is required for this regress
	SKIPPED
	EOF
fi

if testcase "failed"; then
	cat <<-EOF >"$TMP1"
	==== test-ci-revert ====
	enter description, terminated with single '.' or end of file:
	NOTE: This is NOT the log message!
	>> 
	==== test-ci-keywords ====
	enter description, terminated with single '.' or end of file:
	NOTE: This is NOT the log message!
	FAILED

	==== test-ci-keywords2 ====
	enter description, terminated with single '.' or end of file:
	NOTE: This is NOT the log message!
	FAILED
	EOF

	robsd_regress_log - -- -F "$TMP1" <<-EOF
	==== test-ci-keywords ====
	enter description, terminated with single '.' or end of file:
	NOTE: This is NOT the log message!
	FAILED

	==== test-ci-keywords2 ====
	enter description, terminated with single '.' or end of file:
	NOTE: This is NOT the log message!
	FAILED
	EOF
fi

if testcase "failed and skipped"; then
	cat <<-EOF >"$TMP1"
	==== t0 ====
	SKIPPED

	==== t1 ====
	FAILED
	EOF

	robsd_regress_log - -- -F "$TMP1" <<-EOF
	==== t1 ====
	FAILED
	EOF
fi

if testcase "error"; then
	cat <<-EOF >"$TMP1"
	===> aeswrap
	cc   -o aes_wrap aes_wrap.o -lcrypto
	==== run-regress-aes_wrap ====
	./aes_wrap

	===> asn1
	cc -O2 -pipe  -Wall -Wundef -Werror -c asn1basic.c
	asn1basic.c:519:7: error: implicit declaration of function 'ASN1_INTEGER_set_uint64' is invalid in C99
		if (!ASN1_INTEGER_set_uint64(aint, 0)) {
		     ^
	4 errors generated.
	*** Error 1 in asn1 (<sys.mk>:87 'asn1basic.o')
	*** Error 2 in /home/src/regress/lib/libcrypto (<bsd.subdir.mk>:48 'all': @for entry in aead...)
	+ _err=2
	+ exit 2
	robsd-regress-exec: process group exited 2
	EOF

	robsd_regress_log - -- -F "$TMP1" <<-EOF
	===> asn1
	cc -O2 -pipe  -Wall -Wundef -Werror -c asn1basic.c
	asn1basic.c:519:7: error: implicit declaration of function 'ASN1_INTEGER_set_uint64' is invalid in C99
		if (!ASN1_INTEGER_set_uint64(aint, 0)) {
		     ^
	4 errors generated.
	*** Error 1 in asn1 (<sys.mk>:87 'asn1basic.o')
	*** Error 2 in /home/src/regress/lib/libcrypto (<bsd.subdir.mk>:48 'all': @for entry in aead...)
	EOF
fi

if testcase "expected fail"; then
	cat <<-EOF >"$TMP1"
	===> subdir
	==== one ====
	./one

	==== two ====
	./two
	EXPECTED_FAIL
	EOF

	robsd_regress_log - -- -X "$TMP1" <<-EOF
	==== two ====
	./two
	EXPECTED_FAIL
	EOF
fi

if testcase "unexpected pass"; then
	cat <<-EOF >"$TMP1"
	==== fail ====
	./fail
	FAILED

	==== unexpected ====
	./unexpected
	UNEXPECTED_PASS
	EOF

	robsd_regress_log - -- -F "$TMP1" <<-EOF
	==== fail ====
	./fail
	FAILED

	==== unexpected ====
	./unexpected
	UNEXPECTED_PASS
	EOF
fi

if testcase "multiple paths"; then
	_failed="${TSHDIR}/failed"
	cat <<-EOF >"$_failed"
	==== test ====
	FAILED
	EOF

	_skipped="${TSHDIR}/skipped"
	cat <<-EOF >"$_skipped"
	==== skip ====
	SKIPPED
	EOF

	_empty="${TSHDIR}/empty"
	: >"$_empty"

	_absent="${TSHDIR}/absent"

	robsd_regress_log - -- -FS "$_failed" "$_skipped" "$_empty" <<-EOF
	==== test ====
	FAILED

	==== skip ====
	SKIPPED
	EOF

	robsd_regress_log -e -e - -- \
		-F "$_failed" "$_skipped" "$_empty" "$_absent" <<-EOF
robsd-regress-log: open: ${_absent}: No such file or directory
	EOF

fi

if testcase "missing arguments"; then
	robsd_regress_log -e >"$TMP1"
	if ! grep -q usage "$TMP1"; then
		fail - "expected usage" <"$TMP1"
	fi
fi
