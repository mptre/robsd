portable no

if testcase "basic"; then
	cat <<-'EOF' >"${TSHDIR}/sysctl"
	case "$2" in
	hw.perfpolicy)	echo auto;;
	hw.setperf)	echo 100;;
	esac
	EOF
	chmod u+x "${TSHDIR}/sysctl"

	if ! PATH="${TSHDIR}:${PATH}" check_perf >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
fi

if testcase "not available"; then
	cat <<-'EOF' >"${TSHDIR}/sysctl"
	echo "value is not available" 1>&2
	EOF
	chmod u+x "${TSHDIR}/sysctl"

	if ! PATH="${TSHDIR}:${PATH}" check_perf >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
fi
