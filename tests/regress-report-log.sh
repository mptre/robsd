. "${EXECDIR}/util-regress.sh"

LOG="${TSHDIR}/log"

if testcase "skipped"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "test"
	EOF

	cat <<-EOF >"$LOG"
	cc   -o optionstest optionstest.o apps.o -lcrypto -lssl

	===> x509
	missing package p5-IO-Socket-SSL
	SKIPPED
	===> second
	SKIPPED
	EOF

	(setmode "robsd-regress" &&
	 regress_report_log -e 0 -n test -l "$LOG" -t "$TSHDIR" >"$TMP1")

	assert_file - "$TMP1" <<-EOF
	===> x509
	missing package p5-IO-Socket-SSL
	SKIPPED

	===> second
	SKIPPED
	EOF
fi

if testcase "skipped many lines"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "test"
	EOF

	cat <<-EOF >"$LOG"
	==== test
	SKIPPED
	EOF
	cat <<-EOF >"$LOG"
	==== t-permit-1 ====
	t-permit-1

	==== t-run-keepenv-path ====
	All of directories we are allowed to use for temporary data
	(/home/src/regress/usr.bin/doas/obj /tmp)
	lie on nosuid filesystems, so we cannot run doas there.
	SKIPPED
	EOF

	(setmode "robsd-regress" &&
	 regress_report_log -e 0 -n test -l "$LOG" -t "$TSHDIR" >"$TMP1")

	assert_file - "$TMP1" <<-EOF
	==== t-run-keepenv-path ====
	All of directories we are allowed to use for temporary data
	(/home/src/regress/usr.bin/doas/obj /tmp)
	lie on nosuid filesystems, so we cannot run doas there.
	SKIPPED
	EOF
fi

if testcase "skipped no lines"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "test"
	EOF
	cat <<-EOF >"$LOG"
	==== test
	SKIPPED
	EOF

	(setmode "robsd-regress" &&
	 regress_report_log -e 0 -n test -l "$LOG" -t "$TSHDIR" >"$TMP1")

	assert_file - "$TMP1" <<-EOF
	==== test
	SKIPPED
	EOF
fi

if testcase "skipped early without marker"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "test"
	EOF
	cat <<-EOF >"$LOG"
	+ trace1
	package test is required for this regress
	SKIPPED
	+ trace2
	package test is required for this regress
	SKIPPED
	+ trace3
	EOF

	(setmode "robsd-regress" &&
	 regress_report_log -e 0 -n test -l "$LOG" -t "$TSHDIR" >"$TMP1")

	assert_file - "$TMP1" <<-EOF
	package test is required for this regress
	SKIPPED

	+ trace2
	package test is required for this regress
	SKIPPED
	EOF
fi

if testcase "tail fallback"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "test"
	EOF

	cat <<-EOF >"$LOG"
	===> tlsext
	more lines than the tail(1) default of 10
	...
	...
	...
	...
	...
	...
	...
	...
	...
	...
	...
	robsd-regress-exec: process group exited 2
	EOF

	(setmode "robsd-regress" &&
	 regress_report_log -e 0 -n test -l "$LOG" -t "$TSHDIR" >"$TMP1")

	assert_file - "$TMP1" <<-EOF
	...
	...
	...
	...
	...
	...
	...
	...
	...
	robsd-regress-exec: process group exited 2
	EOF
fi

if testcase "failed"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "test"
	EOF

	cat <<-EOF >"$LOG"
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

	(setmode "robsd-regress" &&
	 regress_report_log -e 0 -n test -l "$LOG" -t "$TSHDIR" >"$TMP1")

	assert_file - "$TMP1" <<-EOF
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
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "test" quiet
	EOF

	cat <<-EOF >"$LOG"
	==== t0 ====
	SKIPPED

	==== t1 ====
	FAILED
	EOF

	(setmode "robsd-regress" &&
	 regress_report_log -e 1 -n test -l "$LOG" -t "$TSHDIR" >"$TMP1")

	assert_file - "$TMP1" <<-EOF
	==== t1 ====
	FAILED
	EOF
fi

if testcase "error"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "test" quiet
	EOF

	cat <<-EOF >"$LOG"
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

	(setmode "robsd-regress" &&
	 regress_report_log -e 1 -n test -l "$LOG" -t "$TSHDIR" >"$TMP1")

	assert_file - "$TMP1" <<-EOF
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
