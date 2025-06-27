portable no

. "${EXECDIR}/util-regress.sh"

if testcase "basic"; then
	{
		step_serialize -n one -d 1
		step_serialize -H -n two -d 2
		step_serialize -H -n end -d 3
	} >"${TMP1}"

	assert_eq "3" "$(duration_total -s "${TMP1}")"
fi

if testcase "robsd-regress"; then
	{
		step_serialize -n one -t 1666666666
		step_serialize -H -n end -t $((1666666666 + 42))
	} >"${TMP1}"

	assert_eq "42" "$(setmode robsd-regress && duration_total -s "${TMP1}")"
fi
