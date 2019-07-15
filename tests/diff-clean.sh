if testcase "basic"; then
	mkdir "${WRKDIR}/diff"
	(cd "${WRKDIR}/diff" && touch a.c a.c.orig a.c.rej .#a.c.1.1)

	# Suppress xargs(1) output.
	diff_clean "${WRKDIR}/diff" 2>/dev/null

	if ! [ -e "${WRKDIR}/diff/a.c" ]; then
		fail "expected a.c to be present"
	fi
	if [ -e "${WRKDIR}/diff/a.c.orig" ]; then
		fail "expected a.c.orig to not be present"
	fi
	if [ -e "${WRKDIR}/diff/a.c.rej" ]; then
		fail "expected a.c.rej to not be present"
	fi
	if [ -e "${WRKDIR}/diff/.#a.c.1.1" ]; then
		fail "expected .#a.c.1.1 to not be present"
	fi
fi
