if testcase "basic"; then
	assert_eq "2" "$(step_id cvs)"
fi

if testcase "unknown"; then
	if step_id foo 2>/dev/null; then
		fatal "expected step not be resolved"
	fi
fi
