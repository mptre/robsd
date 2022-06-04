if testcase "basic"; then
	if ! report_skip -b "$TSHDIR" -n "end" -l "/dev/null"; then
		fail "expected end to be skipped"
	fi
	if report_skip -b "$TSHDIR" -n "cvs" -l "/dev/null"; then
		fail "expected cvs to not be skipped"
	fi
fi

if testcase "checkflist empty"; then
	cat <<-EOF >"$TMP1"
	+ checkflist
	EOF

	if ! report_skip -b "$TSHDIR" -n "checkflist" -l "$TMP1"; then
		fail "expected checkflist to be skipped"
	fi
fi

if testcase "checkflist not empty"; then
	cat <<-EOF >"$TMP1"
	+ checkflist
	> ./usr/share/man/man1/ls.1
	EOF

	if report_skip -b "$TSHDIR" -n "checkflist" -l "$TMP1"; then
		fail "expected checkflist to not be skipped"
	fi
fi

if testcase "diff src present"; then
	: >"${TSHDIR}/src.diff.1"

	if report_skip -b "$TSHDIR" -n "patch" -l "/dev/null"; then
		fail "expected patch to not be skipped"
	fi
	if report_skip -b "$TSHDIR" -n "revert" -l "/dev/null"; then
		fail "expected revert to not be skipped"
	fi
fi

if testcase "diff xenocara present"; then
	: >"${TSHDIR}/xenocara.diff.1"

	if report_skip -b "$TSHDIR" -n "patch" -l "/dev/null"; then
		fail "expected patch to not be skipped"
	fi
	if report_skip -b "$TSHDIR" -n "revert" -l "/dev/null"; then
		fail "expected revert to not be skipped"
	fi
fi

if testcase "diff not present"; then
	if ! report_skip -b "$TSHDIR" -n "patch" -l "/dev/null"; then
		fail "expected patch to be skipped"
	fi
	if ! report_skip -b "$TSHDIR" -n "revert" -l "/dev/null"; then
		fail "expected revert to be skipped"
	fi
fi

if testcase "ports"; then
	if (setmode "robsd-ports" &&
	    PORTS="" report_skip -b "$TSHDIR" -n "devel/skip" -l "/dev/null")
	then
		:
	else
		fail "expected step to be skipped"
	fi
fi

if testcase "regress"; then
	robsd_config -R - <<-EOF
	robsddir "${ROBSDDIR}"
	regress "test"
	EOF

	if (setmode "robsd-regress" &&
	    report_skip -b "$TSHDIR" -n "bin/cat" -l "/dev/null" -t "$TSHDIR")
	then
		:
	else
		fail "expected step to be skipped"
	fi
fi

if testcase "regress skip"; then
	robsd_config -R - <<-EOF
	robsddir "${ROBSDDIR}"
	regress "bin/w" quiet
	EOF
	cat <<-EOF >"$TMP1"
	==== t0 ====
	SKIPPED

	==== t1 ====
	DISABLED
	EOF

	if (setmode "robsd-regress" &&
	    report_skip -b "$TSHDIR" -n "bin/w" -l "$TMP1" -t "$TSHDIR")
	then
		:
	else
		fail "expected step to be skipped"
	fi
fi
