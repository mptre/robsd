# default_steps
default_steps() {
	step_serialize -s 1 -n one
	step_serialize -H -s 2 -n two
}

if testcase "positive offset"; then
	default_steps >"${TMP1}"

	step_eval 1 "${TMP1}"
	assert_eq "1" "$(step_value step)" "one: id"
	assert_eq "one" "$(step_value name)" "one: name"

	step_eval 2 "${TMP1}"
	assert_eq "2" "$(step_value step)" "two: id"
	assert_eq "two" "$(step_value name)" "two: name"
fi

if testcase "negative offset"; then
	default_steps >"${TMP1}"

	step_eval -1 "${TMP1}"
	assert_eq "2" "$(step_value step)" "two: id"
	assert_eq "two" "$(step_value name)" "two: name"

	step_eval -2 "${TMP1}"
	assert_eq "1" "$(step_value step)" "one: id"
	assert_eq "one" "$(step_value name)" "one: name"
fi

if testcase "name"; then
	default_steps >"${TMP1}"

	step_eval -n one "${TMP1}"
	assert_eq "1" "$(step_value step)" "one: id"
	assert_eq "one" "$(step_value name)" "one: name"
fi

if testcase "invalid: unknown field"; then
	default_steps >"${TMP1}"

	step_eval -n one "${TMP1}"
	if step_value nein 2>/dev/null; then
		fail "expected step field to not be recognized"
	fi
fi
