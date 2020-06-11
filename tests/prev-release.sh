if testcase "basic"; then
	# shellcheck disable=SC2086
	mkdir -p ${BUILDDIR}/2019-07-{20,21}
	LOGDIR="${BUILDDIR}/2019-07-21"; export LOGDIR
	assert_eq "${BUILDDIR}/2019-07-20" "$(prev_release)"
fi

if testcase "count"; then
	# shellcheck disable=SC2086
	mkdir -p ${BUILDDIR}/2019-07-{19,20,21}
	LOGDIR="${BUILDDIR}/2019-07-21"; export LOGDIR
	prev_release 2 >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	${BUILDDIR}/2019-07-20
	${BUILDDIR}/2019-07-19
	EOF
fi

if testcase "all"; then
	# shellcheck disable=SC2086
	mkdir -p ${BUILDDIR}/2019-07-{19,20,21}
	LOGDIR="${BUILDDIR}/2019-07-21"; export LOGDIR
	prev_release 0 >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	${BUILDDIR}/2019-07-20
	${BUILDDIR}/2019-07-19
	EOF
fi
