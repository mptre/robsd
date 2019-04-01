# zero size path
zero() {
	[ -e "$2" ] && : >"$2"
	dd if=/dev/zero "of=${2}" "bs=${1}" count=1 2>/dev/null
}

NAME="$(basename "$TMP1")"

if testcase "previous release missing"; then
	assert_eq "${NAME} 0" "$(report_size "$TMP1")"
fi

if testcase "previous release missing file"; then
	zero 1K "$TMP1"
	LOGDIR="${BUILDDIR}/2019-02-23"
	mkdir -p ${BUILDDIR}/2019-02-{22,23}/reldir

	assert_eq "${NAME} 1.0K" "$(report_size "$TMP1")"
fi

if testcase "previous delta too small"; then
	zero 1K "$TMP1"
	LOGDIR="${BUILDDIR}/2019-02-23"
	mkdir -p ${BUILDDIR}/2019-02-{22,23}/reldir
	zero 1K "${BUILDDIR}/2019-02-22/reldir/${NAME}"

	assert_eq "${NAME} 1.0K" "$(report_size "$TMP1")"
fi

if testcase "previous delta kilobytes"; then
	zero 2K "$TMP1"
	LOGDIR="${BUILDDIR}/2019-02-23"
	mkdir -p ${BUILDDIR}/2019-02-{22,23}/reldir
	zero 1K "${BUILDDIR}/2019-02-22/reldir/${NAME}"

	assert_eq "${NAME} 2.0K (+1.0K)" "$(report_size "$TMP1")"
fi

if testcase "previous delta megabytes"; then
	zero 2M "$TMP1"
	LOGDIR="${BUILDDIR}/2019-02-23"
	mkdir -p ${BUILDDIR}/2019-02-{22,23}/reldir
	zero 1K "${BUILDDIR}/2019-02-22/reldir/${NAME}"

	assert_eq "${NAME} 2.0M (+2.0M)" "$(report_size "$TMP1")"
fi

if testcase "previous delta negative"; then
	zero 1K "$TMP1"
	LOGDIR="${BUILDDIR}/2019-02-23"
	mkdir -p ${BUILDDIR}/2019-02-{22,23}/reldir
	zero 2M "${BUILDDIR}/2019-02-22/reldir/${NAME}"

	assert_eq "${NAME} 1.0K (-2.0M)" "$(report_size "$TMP1")"
fi
