portable no

if testcase "basic"; then
	assert_eq "01:00:00 (+00:30:00)" "$(report_duration -d 1800 3600)"
fi

if testcase "delta negative"; then
	assert_eq "00:30:00 (-00:30:00)" "$(report_duration -d -1800 1800)"
fi

if testcase "delta below threshold"; then
	assert_eq "00:01:00" "$(report_duration -d 30 -t 30 60)"
fi

if testcase "no delta"; then
	assert_eq "01:00:00" "$(report_duration 3600)"
fi
