. "${EXECDIR}/util-ports.sh"

TMP1="${TSHDIR}/tmp1"
TMP2="${TSHDIR}/tmp2"

if testcase "step port exit non-zero"; then
	cat <<-EOF >"$TMP1"
	error
	EOF
	ports_report_log -e 1 -n test -l "$TMP1" -t "$TSHDIR" >"$TMP2"
	assert_file "$TMP2" - <<-EOF
	error
	EOF
fi
