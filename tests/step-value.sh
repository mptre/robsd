portable no

if testcase "basic"; then
	step_serialize -n test -t 1 >"$TMP1"
	if ! step_eval -n test "$TMP1"; then
		fail "expected step to evaluate"
	fi
	if ! step_value name >/dev/null 2>&1; then
		fail "expected field to be present"
	fi
	assert_eq "1" "$(step_value time)"
fi
