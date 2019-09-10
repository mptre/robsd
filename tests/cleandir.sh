if testcase "entries are removed"; then
	mkdir -p "${TSHDIR}/clean/foo"
	touch "${TSHDIR}/clean/bar"
	cleandir "${TSHDIR}/clean"
	assert_eq "" "$(find "${TSHDIR}/clean" -mindepth 1)"
fi

if testcase "hidden entries are removed"; then
	mkdir -p "${TSHDIR}/clean"
	touch "${TSHDIR}/clean/.foo"
	cleandir "${TSHDIR}/clean"
	assert_eq "" "$(find "${TSHDIR}/clean" -mindepth 1)"
fi
