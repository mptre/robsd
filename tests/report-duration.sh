if testcase "basic"; then
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	echo "${TSHDIR}/2019-02-23" >"${TSHDIR}/.running"
	# shellcheck disable=SC2086
	mkdir -p ${TSHDIR}/2019-02-{22,23}
	step_serialize -n end -d 1800 >"$(step_path "${TSHDIR}/2019-02-22")"

	assert_eq "01:00:00 (+00:30:00)" "$(report_duration -d end 3600)"
fi

if testcase "delta negative"; then
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	echo "${TSHDIR}/2019-02-23" >"${TSHDIR}/.running"
	# shellcheck disable=SC2086
	mkdir -p ${TSHDIR}/2019-02-{22,23}
	step_serialize -n end -d 3600 >"$(step_path "${TSHDIR}/2019-02-22")"

	assert_eq "00:30:00 (-00:30:00)" "$(report_duration -d end 1800)"
fi

if testcase "delta below threshold"; then
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	echo "${TSHDIR}/2019-02-23" >"${TSHDIR}/.running"
	# shellcheck disable=SC2086
	mkdir -p ${TSHDIR}/2019-02-{22,23}
	step_serialize -n end -d 30 >"$(step_path "${TSHDIR}/2019-02-22")"

	assert_eq "00:01:00" "$(report_duration -d end -t 30 60)"
fi

if testcase "previous build failed"; then
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	echo "${TSHDIR}/2019-02-23" >"${TSHDIR}/.running"
	# shellcheck disable=SC2086
	mkdir -p ${TSHDIR}/2019-02-{22,23}
	step_serialize -n kernel -e 1 -d 3600 \
		>"$(step_path "${TSHDIR}/2019-02-22")"

	assert_eq "00:30:00" \
		"$(report_duration -d end 1800)"
fi

if testcase "previous failed and successful"; then
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	echo "${TSHDIR}/2019-02-23" >"${TSHDIR}/.running"
	# shellcheck disable=SC2086
	mkdir -p ${TSHDIR}/2019-02-{21,22,23}
	step_serialize -n kernel -e 1 -d 3600 \
		>"$(step_path "${TSHDIR}/2019-02-22")"
	step_serialize -n end -d 3600 >"$(step_path "${TSHDIR}/2019-02-21")"

	assert_eq "00:30:00 (-00:30:00)" "$(report_duration -d end 1800)"
fi

if testcase "previous build absent"; then
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	echo "${TSHDIR}/2019-02-23" >"${TSHDIR}/.running"
	assert_eq "00:30:00" "$(report_duration -d end 1800)"
fi

if testcase "no delta"; then
	assert_eq "01:00:00" "$(report_duration 3600)"
fi
