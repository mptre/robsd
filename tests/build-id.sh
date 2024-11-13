portable no

setup() {
	cat <<-EOF >"${TSHDIR}/date"
	echo 2024-10-23
	EOF
	chmod u+x "${TSHDIR}/date"

	mkdir "${TSHDIR}/robsd"
}

if testcase "no previous invocation(s)"; then
	assert_eq "2024-10-23.1" "$(PATH="${TSHDIR}:${PATH}" build_id "${TSHDIR}/robsd")"
fi

if testcase "one previous invocation(s)"; then
	mkdir "${TSHDIR}/robsd/2024-10-23.1"
	assert_eq "2024-10-23.2" "$(PATH="${TSHDIR}:${PATH}" build_id "${TSHDIR}/robsd")"
fi

if testcase "gap in previous invocation(s)"; then
	mkdir "${TSHDIR}/robsd/2024-10-23.2"
	assert_eq "2024-10-23.3" "$(PATH="${TSHDIR}:${PATH}" build_id "${TSHDIR}/robsd")"
fi
