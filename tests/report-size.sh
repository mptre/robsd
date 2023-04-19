portable no

# zero size path
zero() {
	[ -e "$2" ] && : >"$2"
	dd if=/dev/zero "of=${2}" "bs=${1}" count=1 2>/dev/null
}

_file="$(basename "$TMP1")"

if testcase "previous release missing"; then
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	assert_eq "" "$(report_size "$TMP1")"
fi

if testcase "previous release missing file"; then
	zero 1K "$TMP1"
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	echo "${TSHDIR}/2019-02-23" >"${TSHDIR}/.running"
	# shellcheck disable=SC2086
	mkdir -p ${TSHDIR}/2019-02-{22,23}/rel

	assert_eq "" "$(report_size "$TMP1")"
fi

if testcase "previous delta too small"; then
	zero 1K "$TMP1"
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	echo "${TSHDIR}/2019-02-23" >"${TSHDIR}/.running"
	# shellcheck disable=SC2086
	mkdir -p ${TSHDIR}/2019-02-{22,23}/rel
	zero 1K "${TSHDIR}/2019-02-22/rel/${_file}"

	assert_eq "" "$(report_size "$TMP1")"
fi

if testcase "previous delta megabytes"; then
	zero "$((1024 * 1024 + 438902))" "$TMP1"
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	echo "${TSHDIR}/2019-02-23" >"${TSHDIR}/.running"
	# shellcheck disable=SC2086
	mkdir -p ${TSHDIR}/2019-02-{22,23}/rel
	zero "$((1024 * 1024))" "${TSHDIR}/2019-02-22/rel/${_file}"

	assert_eq "${_file} 1.4M (+428.6K)" "$(report_size "$TMP1")"
fi

if testcase "previous delta negative"; then
	zero 1K "$TMP1"
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	echo "${TSHDIR}/2019-02-23" >"${TSHDIR}/.running"
	# shellcheck disable=SC2086
	mkdir -p ${TSHDIR}/2019-02-{22,23}/rel
	zero 2M "${TSHDIR}/2019-02-22/rel/${_file}"

	assert_eq "${_file} 1.0K (-2.0M)" "$(report_size "$TMP1")"
fi
