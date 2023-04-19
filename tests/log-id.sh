portable no

if testcase "basic"; then
	assert_eq "001-env.log" "$(log_id -b "$TSHDIR" -n env -s 1)"
	assert_eq "010-env.log" "$(log_id -b "$TSHDIR" -n env -s 10)"
fi

if testcase "duplicates"; then
	touch "${TSHDIR}/001-env.log"
	assert_eq "001-env.log.1" "$(log_id -b "$TSHDIR" -n env -s 1)"

	touch "${TSHDIR}/001-env.log.1"
	assert_eq "001-env.log.2" "$(log_id -b "$TSHDIR" -n env -s 1)"
fi

if testcase "regress"; then
	assert_eq "001-bin-cat.log" \
		"$(setmode "robsd-regress" && log_id -b "$TSHDIR" -n bin/cat -s 1)"
fi
