LOG="${TSHDIR}/log"

if testcase "skipped"; then
	cat <<-EOF >"$LOG"
	cc   -o optionstest optionstest.o apps.o -lcrypto -lssl

	===> x509
	missing package p5-IO-Socket-SSL
	SKIPPED
	===> second
	SKIPPED
	EOF

	regress_report_log -e 0 -n test -l "$LOG" -t "$TSHDIR" >"$TMP1"

	assert_file - "$TMP1" <<-EOF
	cc   -o optionstest optionstest.o apps.o -lcrypto -lssl

	===> x509
	missing package p5-IO-Socket-SSL
	SKIPPED
	===> second
	SKIPPED
	EOF
fi

if testcase "skipped many lines"; then
	cat <<-EOF >"$LOG"
	==== t-permit-1 ====
	t-permit-1

	==== t-run-keepenv-path ====
	All of directories we are allowed to use for temporary data
	(/home/src/regress/usr.bin/doas/obj /tmp)
	lie on nosuid filesystems, so we cannot run doas there.
	SKIPPED
	EOF

	regress_report_log -e 0 -n test -l "$LOG" -t "$TSHDIR" >"$TMP1"

	assert_file - "$TMP1" <<-EOF
	==== t-run-keepenv-path ====
	All of directories we are allowed to use for temporary data
	(/home/src/regress/usr.bin/doas/obj /tmp)
	lie on nosuid filesystems, so we cannot run doas there.
	SKIPPED
	EOF
fi

if testcase "skipped no lines"; then
	cat <<-EOF >"$LOG"
	==== test
	SKIPPED
	EOF

	regress_report_log -e 0 -n test -l "$LOG" -t "$TSHDIR" >"$TMP1"

	assert_file - "$TMP1" <<-EOF
	==== test
	SKIPPED
	EOF
fi

if testcase "robsd-exec fallback"; then
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

	regress_report_log -e 0 -n test -l "$LOG" -t "$TSHDIR" >"$TMP1"

	assert_file - "$TMP1" <<-EOF
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
fi

if testcase "failed"; then
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

	regress_report_log -e 0 -n test -l "$LOG" -t "$TSHDIR" >"$TMP1"

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
