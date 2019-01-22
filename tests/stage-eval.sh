if testcase "positive offset"; then
	cat <<-EOF >$TMP1
	stage="1" name="one"
	name="two" stage="2"
	EOF

	stage_eval 1 "$TMP1"
	assert_eq "2" "${#_STAGE[*]}" "one: array length"
	assert_eq "1" "${_STAGE[$_STAGE_ID]}" "one: id"
	assert_eq "one" "${_STAGE[$_STAGE_NAME]}" "one: name"

	stage_eval 2 "$TMP1"
	assert_eq "2" "${#_STAGE[*]}" "two: array length"
	assert_eq "2" "${_STAGE[$_STAGE_ID]}" "two: id"
	assert_eq "two" "${_STAGE[$_STAGE_NAME]}" "two: name"

	pass
fi

if testcase "negative offset"; then
	cat <<-EOF >$TMP1
	stage="1" name="one"
	name="two" stage="2"
	EOF

	stage_eval -1 "$TMP1"
	assert_eq "2" "${#_STAGE[*]}" "two: array length"
	assert_eq "2" "${_STAGE[$_STAGE_ID]}" "two: id"
	assert_eq "two" "${_STAGE[$_STAGE_NAME]}" "two: name"

	stage_eval -2 "$TMP1"
	assert_eq "2" "${#_STAGE[*]}" "one: array length"
	assert_eq "1" "${_STAGE[$_STAGE_ID]}" "one: id"
	assert_eq "one" "${_STAGE[$_STAGE_NAME]}" "one: name"

	pass
fi

if testcase "offset not found"; then
	cat </dev/null >$TMP1
	stage_eval 1337 "$TMP1" && fail "bogus offset found"
	pass
fi

if testcase "unknown field"; then
	cat <<-EOF >$TMP1
	bogus="bogus"
	EOF
	stage_eval 1 "$TMP1" 2>/dev/null && fail "bougs field found"
	pass
fi
