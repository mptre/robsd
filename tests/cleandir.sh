if testcase "entries are removed"; then
	mkdir -p "${WRKDIR}/clean/foo"
	touch "${WRKDIR}/clean/bar"
	cleandir "${WRKDIR}/clean"
	assert_eq "" "$(find "${WRKDIR}/clean" -mindepth 1)"
	pass
fi

if testcase "hidden entries are removed"; then
	mkdir -p "${WRKDIR}/clean"
	touch "${WRKDIR}/clean/.foo"
	cleandir "${WRKDIR}/clean"
	assert_eq "" "$(find "${WRKDIR}/clean" -mindepth 1)"
	pass
fi
