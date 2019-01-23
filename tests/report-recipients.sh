BINDIR="${WRKDIR}/bin"

if testcase "user in wheel group"; then
	mkdir "$BINDIR"
	cat <<-EOF >"${BINDIR}/groups"
	echo wheel
	EOF
	chmod +x "${BINDIR}/groups"
	cat <<-EOF >"$TMP1"
	user="foo"
	user="bar"
	EOF

	assert_eq "foo" \
		"$(PATH="${BINDIR}:${PATH}" report_recipients "$TMP1")"
	pass
fi

if testcase "user not in wheel group"; then
	mkdir "$BINDIR"
	cat </dev/null >"${BINDIR}/groups"
	chmod +x "${BINDIR}/groups"
	cat <<-EOF >"$TMP1"
	user="foo"
	user="bar"
	EOF

	assert_eq "root foo" \
		"$(PATH="${BINDIR}:${PATH}" report_recipients "$TMP1")"
	pass
fi
