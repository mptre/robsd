if testcase "stage exit zero"; then
	cat <<-EOF >$TMP1
	stage="0" name="cvs" exit="0"
	EOF

	assert_eq "1" "$(stage_next "$TMP1")"
fi

if testcase "stage exit non-zero"; then
	cat <<-EOF >$TMP1
	stage="0" exit="1"
	EOF

	assert_eq "0" "$(stage_next "$TMP1")"
fi

if testcase "stage end"; then
	cat <<-EOF >$TMP1
	stage="0" name="end" exit="0"
	EOF

	assert_eq "0" "$(stage_next "$TMP1")"
fi
