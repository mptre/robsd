if testcase "basic"; then
	mkdir "${TSHDIR}/diff"
	(cd "${TSHDIR}/diff" && touch a.c a.c.orig a.c.rej .#a.c.1.1)

	# Suppress xargs(1) output.
	diff_clean "${TSHDIR}/diff" >/dev/null

	if ! [ -e "${TSHDIR}/diff/a.c" ]; then
		fail "expected a.c to be present"
	fi
	if [ -e "${TSHDIR}/diff/a.c.orig" ]; then
		fail "expected a.c.orig to not be present"
	fi
	if [ -e "${TSHDIR}/diff/a.c.rej" ]; then
		fail "expected a.c.rej to not be present"
	fi
	if [ -e "${TSHDIR}/diff/.#a.c.1.1" ]; then
		fail "expected .#a.c.1.1 to not be present"
	fi
fi
