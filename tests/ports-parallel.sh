if testcase "basic"; then
	if NOPARALLEL="devel/bad" ports_parallel "devel/bad"; then
		fail "expected exit non-zero"
	fi
	if ! NOPARALLEL="devel/bad" ports_parallel "devel/good"; then
		fail "expected exit zero"
	fi
fi
