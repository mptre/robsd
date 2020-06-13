if testcase "basic"; then
	cat <<-EOF >"$TMP1"
	name="test" time="1"
	EOF

	if ! step_eval -n test "$TMP1"; then
		fail "expected step to evaluate"
	fi
	if ! step_value name >/dev/null 2>&1; then
		fail "expected field to be present"
	fi
	assert_eq "1" "$(step_value time)"
fi

if testcase "field not present"; then
	cat <<-EOF >"$TMP1"
	name="bar"
	EOF

	if ! step_eval 1 "$TMP1"; then
		fail "expected step to evaluate"
	fi
	if step_value id >/dev/null 2>&1; then
		fail "expected field to not be present"
	fi
fi

if testcase "field unknown"; then
	cat <<-EOF >"$TMP1"
	name="bar"
	EOF

	if ! step_eval 1 "$TMP1"; then
		fail "expected step to evaluate"
	fi
	if step_value foo >/dev/null 2>&1; then
		fail "expected field to not be present"
	fi
fi
