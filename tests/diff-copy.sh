if testcase "destination not present"; then
	touch "${WRKDIR}/src.diff"
	assert_eq "${WRKDIR}/dst.diff" \
		"$(diff_copy "${WRKDIR}/src.diff" "${WRKDIR}/dst.diff")"
	if ! [ -e "${WRKDIR}/dst.diff" ]; then
		fail "expected dst.diff to be present"
	fi
fi

if testcase "destination present"; then
	touch ${WRKDIR}/{src,dst}.diff
	if diff_copy "${WRKDIR}/src.diff" "${WRKDIR}/dst.diff"; then
		fail "expected diff_copy to exit non-zero"
	fi
fi

if testcase "empty source"; then
	assert_eq "" "$(diff_copy "" "${WRKDIR}/dst.diff")"
	if [ -e "${WRKDIR}/dst.diff" ]; then
		fail "expected dst.diff to not be present"
	fi
fi
