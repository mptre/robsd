if testcase "positive offset"; then
	cat <<-EOF >$TMP1
	stage="1" name="one"
	name="two" stage="2"
	EOF

	stage_eval 1 "$TMP1"
	assert_eq "2" "${#_STAGE[*]}" "one: array length"
	assert_eq "1" "$(stage_value stage)" "one: id"
	assert_eq "one" "$(stage_value name)" "one: name"

	stage_eval 2 "$TMP1"
	assert_eq "2" "${#_STAGE[*]}" "two: array length"
	assert_eq "2" "$(stage_value stage)" "two: id"
	assert_eq "two" "$(stage_value name)" "two: name"
fi

if testcase "negative offset"; then
	cat <<-EOF >$TMP1
	stage="1" name="one"
	name="two" stage="2"
	EOF

	stage_eval -1 "$TMP1"
	assert_eq "2" "${#_STAGE[*]}" "two: array length"
	assert_eq "2" "$(stage_value stage)" "two: id"
	assert_eq "two" "$(stage_value name)" "two: name"

	stage_eval -2 "$TMP1"
	assert_eq "2" "${#_STAGE[*]}" "one: array length"
	assert_eq "1" "$(stage_value stage)" "one: id"
	assert_eq "one" "$(stage_value name)" "one: name"
fi

if testcase "offset not found"; then
	cat </dev/null >$TMP1
	stage_eval 1337 "$TMP1" && fail "bogus offset found"
fi

if testcase "name"; then
	cat <<-EOF >$TMP1
	name="one" stage="1"
	EOF

	stage_eval -n one "$TMP1"
	assert_eq "2" "${#_STAGE[*]}" "one: array length"
	assert_eq "1" "$(stage_value stage)" "one: id"
	assert_eq "one" "$(stage_value name)" "one: name"
fi

if testcase "name not found"; then
	cat <<-EOF >$TMP1
	name="one" stage="1"
	EOF
	if stage_eval two "$TMP1" 2>/dev/null; then
		fail "bogus field found"
	fi
fi

if testcase "unknown field"; then
	cat <<-EOF >$TMP1
	bogus="bogus"
	EOF
	if stage_eval 1 "$TMP1" 2>/dev/null; then
		fail "bogus field found"
	fi
fi

if testcase "stages file not found"; then
	if stage_eval 1 empty >/dev/null 2>&1; then
		fail "expected non-zero return"
	fi
fi
