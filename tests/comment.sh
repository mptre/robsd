SRC="${TSHDIR}/src"
DST="${TSHDIR}/dst"

if testcase "basic"; then
	echo comment >"$SRC"
	comment "$SRC" "$DST"
	assert_file "$SRC" "$DST"
fi

if testcase "stdin"; then
	echo stdin >"$SRC"
	comment "-" "$DST" <"$SRC"
	assert_file "$SRC" "$DST"
fi

if testcase "destination present"; then
	touch "$DST"
	if comment "$SRC" "$DST"; then
		fail "want exit 1, got 0"
	fi
fi

if testcase "empty comment is removed"; then
	if ! comment "-" "$DST" </dev/null; then
		fail "want exit 0, got 1"
	fi
	if [ -e "$DST" ]; then
		fail "${DST}: destination present"
	fi
fi
