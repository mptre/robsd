if testcase "basic"; then
	assert_eq "01:01:01" "$(duration_format 3661)"
fi

if testcase "zero"; then
	assert_eq "0" "$(duration_format 0)"
fi
