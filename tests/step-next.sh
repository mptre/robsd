if testcase "step exit zero"; then
	step_serialize -s 0 -n cvs -e 0 >"$TMP1"
	assert_eq "1" "$(step_next "$TMP1")"
fi

if testcase "step exit non-zero"; then
	step_serialize -s 0 -n cvs -e 1 >"$TMP1"
	assert_eq "0" "$(step_next "$TMP1")"
fi

if testcase "step aborted"; then
	step_serialize -s 0 -n cvs -e -1 >"$TMP1"
	assert_eq "0" "$(step_next "$TMP1")"
fi

if testcase "step skip"; then
	{
		step_serialize -s 0 -n one -e 1
		step_serialize -s 1 -n two -i 1
	} >"$TMP1"
	assert_eq "0" "$(step_next "$TMP1")"
fi

if testcase "step skip all"; then
	step_serialize -s 0 -i 1 >"$TMP1"
	if step_next "$TMP1" 2>/dev/null; then
		fail "want exit 1, got 0"
	fi
fi

if testcase "step end"; then
	step_serialize -s 0 -n end -e 0 >"$TMP1"
	assert_eq "0" "$(step_next "$TMP1")"
fi
