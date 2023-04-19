portable no

ROBSDCROSSENV="${EXECDIR}/robsd-crossenv"

if testcase "basic"; then
	robsd_config -C - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	cat <<-EOF >"${TSHDIR}/Makefile.cross"
	cross-env:
	EOF

	if ! sh "$ROBSDCROSSENV" amd64 echo hello >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	echo hello | assert_file - "$TMP1"
fi
