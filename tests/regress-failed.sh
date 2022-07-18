. "${EXECDIR}/util-regress.sh"

if testcase "failure"; then
	cat <<-EOF >"$TMP1"
	*** Error 1 in edit (Makefile:15 'vi')
	FAILED
	EOF
	if ! regress_failed "$TMP1"; then
		fail "expected exit zero"
	fi
fi

if testcase "success"; then
	if regress_failed "/dev/null"; then
		fail "expected exit non-zero"
	fi
fi
