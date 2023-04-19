portable no

if testcase "not acquired"; then
	lock_acquire "$TSHDIR" "2021-06-16.1"
	echo "2021-06-16.1" | assert_file "${TSHDIR}/.running" -
fi

if testcase "already acquired"; then
	echo 2021-06-16.1 >"${TSHDIR}/.running"
	if lock_acquire "$TSHDIR" "2021-06-17.1" >"$TMP1"; then
		fail - "expected exit non-zero" <"$TMP1"
	fi
fi

if testcase "already acquired by same owner"; then
	echo 2021-06-16.1 >"${TSHDIR}/.running"
	if ! lock_acquire "$TSHDIR" "2021-06-16.1" >/dev/null; then
		fail "expected exit zero"
	fi
fi
