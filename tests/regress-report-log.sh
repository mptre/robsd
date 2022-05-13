LOG="${TSHDIR}/log"

if testcase "skipped"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress { "test" }
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
	regress { "test" }
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
	regress { "test" }
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

if testcase "tail fallback"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress { "test" }
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
	regress { "test" }
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
	regress { "test:S" }
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
