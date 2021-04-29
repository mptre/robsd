if testcase "destination not present"; then
	touch "${TSHDIR}/src.diff"
	assert_eq "${TSHDIR}/dst.diff.1" \
		"$(diff_copy -d /var/empty "${TSHDIR}/dst.diff" "${TSHDIR}/src.diff" 2>/dev/null)"
	if ! [ -e "${TSHDIR}/dst.diff.1" ]; then
		fail "expected dst.diff.1 to be present"
	fi
fi

if testcase "empty source"; then
	assert_eq "" "$(diff_copy -d /var/empty "${TSHDIR}/dst.diff" 2>/dev/null)"
	if [ -e "${TSHDIR}/dst.diff.1" ]; then
		fail "expected dst.diff.1 to not be present"
	fi
fi

if testcase "many sources"; then
	touch "${TSHDIR}/src.diff.1" "${TSHDIR}/src.diff.2"
	diff_copy -d /var/empty "${TSHDIR}/dst.diff" \
		"${TSHDIR}/src.diff.1" "${TSHDIR}/src.diff.2" >"$TMP1" 2>/dev/null
	assert_file - "$TMP1" <<-EOF
	${TSHDIR}/dst.diff.1 ${TSHDIR}/dst.diff.2
	EOF
	if ! [ -e "${TSHDIR}/dst.diff.1" ]; then
		fail "expected dst.diff.1 to be present"
	fi
	if ! [ -e "${TSHDIR}/dst.diff.2" ]; then
		fail "expected dst.diff.2 to be present"
	fi
fi

if testcase "comment"; then
	touch "${TSHDIR}/src.diff.1"
	diff_copy -d /var/empty "${TSHDIR}/dst.diff" \
		"${TSHDIR}/src.diff.1" >/dev/null 2>/dev/null
	assert_file - "${TSHDIR}/dst.diff.1" <<-EOF
	# ${TSHDIR}/src.diff.1
	EOF
fi
