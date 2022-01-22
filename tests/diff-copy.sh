if testcase "copy not present"; then
	: >"${TSHDIR}/src.diff"
	diff_copy -d /var/empty "${TSHDIR}/dst.diff" "${TSHDIR}/src.diff" >/dev/null
	if ! [ -e "${TSHDIR}/dst.diff.1" ]; then
		fail "expected dst.diff.1 to be present"
	fi
fi

if testcase "many sources"; then
	: >"${TSHDIR}/src.diff.1"
	: >"${TSHDIR}/src.diff.2"
	diff_copy -d /var/empty "${TSHDIR}/dst.diff" \
		"${TSHDIR}/src.diff.1" "${TSHDIR}/src.diff.2" >/dev/null
	if ! [ -e "${TSHDIR}/dst.diff.1" ]; then
		fail "expected dst.diff.1 to be present"
	fi
	if ! [ -e "${TSHDIR}/dst.diff.2" ]; then
		fail "expected dst.diff.2 to be present"
	fi
fi

if testcase "no arguments"; then
	diff_copy -d /var/empty "${TSHDIR}/dst.diff"
	if [ -e "${TSHDIR}/dst.diff.1" ]; then
		fail "expected dst.diff.1 to not be present"
	fi
fi

if testcase "comment"; then
	: >"${TSHDIR}/src.diff.1"
	diff_copy -d /var/empty "${TSHDIR}/dst.diff" \
		"${TSHDIR}/src.diff.1" >/dev/null
	assert_file - "${TSHDIR}/dst.diff.1" <<-EOF
	# ${TSHDIR}/src.diff.1

	EOF
fi
