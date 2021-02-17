if testcase "basic"; then
	if ! report_skip "end" "/dev/null"; then
		fail "expected end to be skipped"
	fi
	if report_skip "cvs" "/dev/null"; then
		fail "expected cvs to not be skipped"
	fi
fi

if testcase "checkflist empty"; then
	cat <<-EOF >"$TMP1"
	+ checkflist
	EOF

	if ! report_skip "checkflist" "$TMP1"; then
		fail "expected checkflist to be skipped"
	fi
fi

if testcase "checkflist not empty"; then
	cat <<-EOF >"$TMP1"
	+ checkflist
	> ./usr/share/man/man1/ls.1
	EOF

	if report_skip "checkflist" "$TMP1"; then
		fail "expected checkflist to not be skipped"
	fi
fi

if testcase "diff src present"; then
	BSDDIFF="src.diff"
	XDIFF=""

	if report_skip "patch"; then
		fail "expected patch to not be skipped"
	fi
	if report_skip "revert"; then
		fail "expected revert to not be skipped"
	fi
fi

if testcase "diff xenocara present"; then
	BSDDIFF=""
	XDIFF="xenocara.diff"

	if report_skip "patch"; then
		fail "expected patch to not be skipped"
	fi
	if report_skip "revert"; then
		fail "expected revert to not be skipped"
	fi
fi

if testcase "diff not present"; then
	BSDDIFF=""; export BSDDIFF
	XDIFF=""; export XDIFF

	if ! report_skip "patch"; then
		fail "expected patch to be skipped"
	fi
	if ! report_skip "revert"; then
		fail "expected revert to be skipped"
	fi
fi

if testcase "regress"; then
	if ! (setmode "robsd-regress" && report_skip "bin/cat"); then
		fail "expected step to be skipped"
	fi
fi
