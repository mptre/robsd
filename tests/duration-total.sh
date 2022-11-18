if testcase "basic"; then
	{
		step_serialize -n one -d 1
		step_serialize -H -n two -d 2
		step_serialize -H -n end -d 3
	} >"$TMP1"

	assert_eq "3" "$(duration_total -s "$TMP1")"
fi
