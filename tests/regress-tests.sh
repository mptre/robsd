LOG="${TSHDIR}/log"

if testcase "basic"; then
	cat <<-EOF >"$LOG"
	cc   -o optionstest optionstest.o apps.o -lcrypto -lssl

	===> x509
	missing package p5-IO-Socket-SSL
	SKIPPED

	===> second
	SKIPPED
	EOF
	regress_tests SKIPPED "$LOG" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	===> x509
	missing package p5-IO-Socket-SSL
	SKIPPED

	===> second
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
	regress_tests SKIPPED "$LOG" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	==== t-run-keepenv-path ====
	All of directories we are allowed to use for temporary data
	(/home/src/regress/usr.bin/doas/obj /tmp)
	lie on nosuid filesystems, so we cannot run doas there.
	SKIPPED
	EOF

	cat <<-EOF >"$LOG"
	==== test
	SKIPPED
	EOF
	regress_tests SKIPPED "$LOG" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	==== test
	SKIPPED
	EOF
fi
