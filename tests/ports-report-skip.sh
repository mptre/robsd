PORTS="test/yes"; export PORTS

if testcase "port"; then
	if ports_report_skip -n "test/yes" -l "/dev/null"; then
		fail "expected exit non-zero"
	fi
fi

if testcase "port dependency"; then
	if ! ports_report_skip -n "test/dependency" -l "/dev/null"; then
		fail "expected exit zero"
	fi
fi
