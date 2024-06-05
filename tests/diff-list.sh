portable no

if testcase "basic"; then
	touch "${TSHDIR}/src.diff.1" "${TSHDIR}/src.diff.2"
	mkdir "${TSHDIR}/rel"
	touch "${TSHDIR}/rel/src.diff.1"

	assert_eq "${TSHDIR}/src.diff.1 ${TSHDIR}/src.diff.2" \
		"$(diff_list "${TSHDIR}" "src.diff" | xargs)"
fi
