if testcase "basic"; then
	touch "${TSHDIR}/src.diff.1" "${TSHDIR}/src.diff.2"

	assert_eq "${TSHDIR}/src.diff.1 ${TSHDIR}/src.diff.2" \
		"$(diff_list "$TSHDIR" "src.diff" | xargs)"
fi
