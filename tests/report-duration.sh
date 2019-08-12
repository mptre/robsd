if testcase "basic"; then
	LOGDIR="${BUILDDIR}/2019-02-23"
	mkdir -p ${BUILDDIR}/2019-02-{22,23}
	cat <<-EOF >${BUILDDIR}/2019-02-22/stages
	name="end" stage="1" duration="1800"
	EOF

	assert_eq "01:00:00 (+00:30:00)" "$(report_duration -d end 3600)"
fi

if testcase "delta negative"; then
	LOGDIR="${BUILDDIR}/2019-02-23"
	mkdir -p ${BUILDDIR}/2019-02-{22,23}
	cat <<-EOF >${BUILDDIR}/2019-02-22/stages
	name="end" stage="1" duration="3600"
	EOF

	assert_eq "00:30:00 (-00:30:00)" "$(report_duration -d end 1800)"
fi

if testcase "delta below threshold"; then
	LOGDIR="${BUILDDIR}/2019-02-23"
	mkdir -p ${BUILDDIR}/2019-02-{22,23}
	cat <<-EOF >${BUILDDIR}/2019-02-22/stages
	name="end" stage="1" duration="30"
	EOF

	assert_eq "00:01:00" "$(report_duration -d end -t 30 60)"
fi

if testcase "previous build failed"; then
	LOGDIR="${BUILDDIR}/2019-02-23"
	mkdir -p ${BUILDDIR}/2019-02-{22,23}
	cat <<-EOF >${BUILDDIR}/2019-02-22/stages
	name="kernel" stage="1" exit="1" duration="3600"
	EOF

	assert_eq "00:30:00" "$(report_duration -d end 1800)"
fi

if testcase "previous failed and successful"; then
	LOGDIR="${BUILDDIR}/2019-02-23"
	mkdir -p ${BUILDDIR}/2019-02-{21,22,23}
	cat <<-EOF >${BUILDDIR}/2019-02-22/stages
	name="kernel" stage="1" exit="1" duration="3600"
	EOF
	cat <<-EOF >${BUILDDIR}/2019-02-21/stages
	name="end" stage="1" exit="0" duration="3600"
	EOF

	assert_eq "00:30:00 (-00:30:00)" "$(report_duration -d end 1800)"
fi

if testcase "previous build absent"; then
	assert_eq "00:30:00" "$(report_duration -d end 1800)"
fi

if testcase "no delta"; then
	assert_eq "01:00:00" "$(report_duration 3600)"
fi
