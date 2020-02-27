if testcase "step exit zero"; then
	cat <<-EOF >"$TMP1"
	step="0" name="cvs" exit="0"
	EOF

	assert_eq "1" "$(step_next "$TMP1")"
fi

if testcase "step exit non-zero"; then
	cat <<-EOF >"$TMP1"
	step="0" exit="1"
	EOF

	assert_eq "0" "$(step_next "$TMP1")"
fi

if testcase "step end"; then
	cat <<-EOF >"$TMP1"
	step="0" name="end" exit="0"
	EOF

	assert_eq "0" "$(step_next "$TMP1")"
fi
