if testcase "basic"; then
	assert_eq "01:01:01" "$(format_duration 3661)"
fi

if testcase "zero"; then
	assert_eq "0" "$(format_duration 0)"
fi