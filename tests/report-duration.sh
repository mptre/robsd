_builddir="${ROBSDDIR}/2019-02-23"

if testcase "basic"; then
	# shellcheck disable=SC2086
	mkdir -p ${ROBSDDIR}/2019-02-{22,23}
	step_serialize -n end -d 1800 >"$(step_path "${ROBSDDIR}/2019-02-22")"

	assert_eq "01:00:00 (+00:30:00)" \
		"$(report_duration -b "$_builddir" -r "$ROBSDDIR" -d end 3600)"
fi

if testcase "delta negative"; then
	# shellcheck disable=SC2086
	mkdir -p ${ROBSDDIR}/2019-02-{22,23}
	step_serialize -n end -d 3600 >"$(step_path "${ROBSDDIR}/2019-02-22")"

	assert_eq "00:30:00 (-00:30:00)" \
		"$(report_duration -b "$_builddir" -r "$ROBSDDIR" -d end 1800)"
fi

if testcase "delta below threshold"; then
	# shellcheck disable=SC2086
	mkdir -p ${ROBSDDIR}/2019-02-{22,23}
	step_serialize -n end -d 30 >"$(step_path "${ROBSDDIR}/2019-02-22")"

	assert_eq "00:01:00" \
		"$(report_duration -b "$_builddir" -r "$ROBSDDIR" -d end -t 30 60)"
fi

if testcase "previous build failed"; then
	# shellcheck disable=SC2086
	mkdir -p ${ROBSDDIR}/2019-02-{22,23}
	step_serialize -n kernel -e 1 -d 3600 \
		>"$(step_path "${ROBSDDIR}/2019-02-22")"

	assert_eq "00:30:00" \
		"$(report_duration -b "$_builddir" -r "$ROBSDDIR" -d end 1800)"
fi

if testcase "previous failed and successful"; then
	# shellcheck disable=SC2086
	mkdir -p ${ROBSDDIR}/2019-02-{21,22,23}
	step_serialize -n kernel -e 1 -d 3600 \
		>"$(step_path "${ROBSDDIR}/2019-02-22")"
	step_serialize -n end -d 3600 >"$(step_path "${ROBSDDIR}/2019-02-21")"

	assert_eq "00:30:00 (-00:30:00)" \
		"$(report_duration -b "$_builddir" -r "$ROBSDDIR" -d end 1800)"
fi

if testcase "previous build absent"; then
	assert_eq "00:30:00" \
		"$(report_duration -b "$_builddir" -r "$ROBSDDIR" -d end 1800)"
fi

if testcase "no delta"; then
	assert_eq "01:00:00" \
		"$(report_duration -b "$_builddir" -r "$ROBSDDIR" 3600)"
fi
