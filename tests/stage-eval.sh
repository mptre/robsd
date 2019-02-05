if testcase "positive offset"; then
	cat <<-EOF >$TMP1
	stage="1" name="one"
	name="two" stage="2"
	EOF

	stage_eval 1 "$TMP1"
	assert_eq "2" "${#_STAGE[*]}" "one: array length"
	assert_eq "1" "${_STAGE[$(stage_field stage)]}" "one: id"
	assert_eq "one" "${_STAGE[$(stage_field name)]}" "one: name"

	stage_eval 2 "$TMP1"
	assert_eq "2" "${#_STAGE[*]}" "two: array length"
	assert_eq "2" "${_STAGE[$(stage_field stage)]}" "two: id"
	assert_eq "two" "${_STAGE[$(stage_field name)]}" "two: name"
fi

if testcase "negative offset"; then
	cat <<-EOF >$TMP1
	stage="1" name="one"
	name="two" stage="2"
	EOF

	stage_eval -1 "$TMP1"
	assert_eq "2" "${#_STAGE[*]}" "two: array length"
	assert_eq "2" "${_STAGE[$(stage_field stage)]}" "two: id"
	assert_eq "two" "${_STAGE[$(stage_field name)]}" "two: name"

	stage_eval -2 "$TMP1"
	assert_eq "2" "${#_STAGE[*]}" "one: array length"
	assert_eq "1" "${_STAGE[$(stage_field stage)]}" "one: id"
	assert_eq "one" "${_STAGE[$(stage_field name)]}" "one: name"
fi

if testcase "offset not found"; then
	cat </dev/null >$TMP1
	stage_eval 1337 "$TMP1" && fail "bogus offset found"
fi

if testcase "unknown field"; then
	cat <<-EOF >$TMP1
	bogus="bogus"
	EOF
	stage_eval 1 "$TMP1" 2>/dev/null && fail "bougs field found"
fi
