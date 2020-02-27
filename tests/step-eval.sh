if testcase "positive offset"; then
	cat <<-EOF >"$TMP1"
	step="1" name="one"
	name="two" step="2"
	EOF

	step_eval 1 "$TMP1"
	assert_eq "2" "${#_STEP[*]}" "one: array length"
	assert_eq "1" "$(step_value step)" "one: id"
	assert_eq "one" "$(step_value name)" "one: name"

	step_eval 2 "$TMP1"
	assert_eq "2" "${#_STEP[*]}" "two: array length"
	assert_eq "2" "$(step_value step)" "two: id"
	assert_eq "two" "$(step_value name)" "two: name"
fi

if testcase "negative offset"; then
	cat <<-EOF >"$TMP1"
	step="1" name="one"
	name="two" step="2"
	EOF

	step_eval -1 "$TMP1"
	assert_eq "2" "${#_STEP[*]}" "two: array length"
	assert_eq "2" "$(step_value step)" "two: id"
	assert_eq "two" "$(step_value name)" "two: name"

	step_eval -2 "$TMP1"
	assert_eq "2" "${#_STEP[*]}" "one: array length"
	assert_eq "1" "$(step_value step)" "one: id"
	assert_eq "one" "$(step_value name)" "one: name"
fi

if testcase "offset not found"; then
	cat </dev/null >"$TMP1"
	step_eval 1337 "$TMP1" && fail "bogus offset found"
fi

if testcase "name"; then
	cat <<-EOF >"$TMP1"
	name="one" step="1"
	EOF

	step_eval -n one "$TMP1"
	assert_eq "2" "${#_STEP[*]}" "one: array length"
	assert_eq "1" "$(step_value step)" "one: id"
	assert_eq "one" "$(step_value name)" "one: name"
fi

if testcase "name not found"; then
	cat <<-EOF >"$TMP1"
	name="one" step="1"
	EOF
	if step_eval two "$TMP1" 2>/dev/null; then
		fail "bogus field found"
	fi
fi

if testcase "unknown field"; then
	cat <<-EOF >"$TMP1"
	bogus="bogus"
	EOF
	if step_eval 1 "$TMP1" 2>/dev/null; then
		fail "bogus field found"
	fi
fi

if testcase "steps file not found"; then
	if step_eval 1 empty >/dev/null 2>&1; then
		fail "expected non-zero return"
	fi
fi
