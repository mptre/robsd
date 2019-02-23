if testcase "basic"; then
	cat <<-EOF >$TMP1
	name="foo" duration="1"
	name="bar" duration="2"
	name="end" duration="3"
	EOF

	assert_eq "3" "$(build_duration "$TMP1")"
fi
