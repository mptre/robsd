if testcase "with previous"; then
	BUILDDIR="${WRKDIR}/release"
	LOGDIR="${BUILDDIR}/2019-02-23"
	mkdir -p ${BUILDDIR}/2019-02-{22,23}
	cat <<-EOF >${BUILDDIR}/2019-02-22/stages
	stage="1" duration="1800"
	EOF

	assert_eq "1h (+30m)" "$(report_duration -s 1 3600)"
fi

if testcase "without previous"; then
	assert_eq "1h" "$(report_duration 3600)"
fi
