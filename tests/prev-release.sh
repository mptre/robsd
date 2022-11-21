if testcase "basic"; then
	# shellcheck disable=SC2086
	mkdir -p ${ROBSDDIR}/2019-07-{20,21}
	prev_release -b "${ROBSDDIR}/2019-07-21" -r "$ROBSDDIR" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	${ROBSDDIR}/2019-07-20
	EOF
fi

if testcase "count"; then
	# shellcheck disable=SC2086
	mkdir -p ${ROBSDDIR}/2019-07-{19,20,21}
	prev_release -b "${ROBSDDIR}/2019-07-21" -r "$ROBSDDIR" 2 >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	${ROBSDDIR}/2019-07-20
	${ROBSDDIR}/2019-07-19
	EOF
fi

if testcase "all"; then
	# shellcheck disable=SC2086
	mkdir -p ${ROBSDDIR}/2019-07-{19,20,21}
	prev_release -b "${ROBSDDIR}/2019-07-21" -r "$ROBSDDIR" 0 >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	${ROBSDDIR}/2019-07-20
	${ROBSDDIR}/2019-07-19
	EOF
fi
