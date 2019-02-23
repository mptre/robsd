if testcase "basic"; then
	assert_eq "1h 1m 1s" "$(duration_format 3661)"
fi

if testcase "hours"; then
	assert_eq "1h" "$(duration_format 3600)"
fi

if testcase "minutes"; then
	assert_eq "1m" "$(duration_format 60)"
fi

if testcase "seconds"; then
	assert_eq "30s" "$(duration_format 30)"
fi

if testcase "zero"; then
	assert_eq "0" "$(duration_format 0)"
fi
