portable no

. "${EXECDIR}/util-regress.sh"

LOG="${TSHDIR}/log"

if testcase "failed and skipped"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "test"
	EOF

	cat <<-EOF >"$LOG"
	==== test ====
	FAILED

	==== skip ====
	SKIPPED
	EOF

	(setmode "robsd-regress" &&
	 regress_report_log -e 0 -n test -l "$LOG" -t "$TSHDIR" >"$TMP1")

	assert_file - "$TMP1" <<-EOF
	==== test ====
	FAILED

	==== skip ====
	SKIPPED
	EOF
fi

if testcase "quiet"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "test" quiet
	EOF

	cat <<-EOF >"$LOG"
	===> x509
	SKIPPED
	EOF

	(setmode "robsd-regress" &&
	 regress_report_log -e 0 -n test -l "$LOG" -t "$TSHDIR" >"$TMP1")

	assert_file - "$TMP1" <<-EOF
	===> x509
	SKIPPED
	EOF
fi


if testcase "fallback"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "test"
	EOF

	cat <<-EOF >"$LOG"
	nothing
	EOF

	(setmode "robsd-regress" &&
	 regress_report_log -e 0 -n test -l "$LOG" -t "$TSHDIR" >"$TMP1")

	assert_file - "$TMP1" <<-EOF
	nothing
	EOF
fi
