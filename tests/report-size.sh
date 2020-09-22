# zero size path
zero() {
	[ -e "$2" ] && : >"$2"
	dd if=/dev/zero "of=${2}" "bs=${1}" count=1 2>/dev/null
}

FILE="$(basename "$TMP1")"
# Used by prev_release.
LOGDIR="${BUILDDIR}/2019-02-23"; export LOGDIR

if testcase "previous release missing"; then
	assert_eq "" "$(report_size "$TMP1")"
fi

if testcase "previous release missing file"; then
	zero 1K "$TMP1"
	# shellcheck disable=SC2086
	mkdir -p ${BUILDDIR}/2019-02-{22,23}/rel

	assert_eq "" "$(report_size "$TMP1")"
fi

if testcase "previous delta too small"; then
	zero 1K "$TMP1"
	# shellcheck disable=SC2086
	mkdir -p ${BUILDDIR}/2019-02-{22,23}/rel
	zero 1K "${BUILDDIR}/2019-02-22/rel/${FILE}"

	assert_eq "" "$(report_size "$TMP1")"
fi

if testcase "previous delta megabytes"; then
	zero "$((1024 * 1024 + 438902))" "$TMP1"
	# shellcheck disable=SC2086
	mkdir -p ${BUILDDIR}/2019-02-{22,23}/rel
	zero "$((1024 * 1024))" "${BUILDDIR}/2019-02-22/rel/${FILE}"

	assert_eq "${FILE} 1.4M (+0.4M)" "$(report_size "$TMP1")"
fi

if testcase "previous delta negative"; then
	zero 1K "$TMP1"
	# shellcheck disable=SC2086
	mkdir -p ${BUILDDIR}/2019-02-{22,23}/rel
	zero 2M "${BUILDDIR}/2019-02-22/rel/${FILE}"

	assert_eq "${FILE} 1.0K (-2.0M)" "$(report_size "$TMP1")"
fi
