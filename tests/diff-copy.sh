if testcase "destination not present"; then
	touch "${TSHDIR}/src.diff"
	assert_eq "${TSHDIR}/dst.diff" \
		"$(diff_copy "${TSHDIR}/src.diff" "${TSHDIR}/dst.diff")"
	if ! [ -e "${TSHDIR}/dst.diff" ]; then
		fail "expected dst.diff to be present"
	fi
fi

if testcase "destination present"; then
	echo a >${TSHDIR}/src.diff
	echo b >${TSHDIR}/dst.diff
	if diff_copy "${TSHDIR}/src.diff" "${TSHDIR}/dst.diff"; then
		fail "expected diff_copy to exit non-zero"
	fi
fi

if testcase "empty source"; then
	assert_eq "" "$(diff_copy "" "${TSHDIR}/dst.diff")"
	if [ -e "${TSHDIR}/dst.diff" ]; then
		fail "expected dst.diff to not be present"
	fi
fi
