utility_setup >"$TMP1"; read -r _ BINDIR BUILDDIR <"$TMP1"

ROBSDREGRESS="${EXECDIR}/robsd-regress"

if testcase "basic"; then
	config_stub - "robsd-regress" <<-EOF
	BUILDDIR=${BUILDDIR}
	EXECDIR=${EXECDIR}
	REGRESSUSER=nobody
	TESTS="fail hello:P"
	EOF
	mkdir "$BUILDDIR"
	mkdir -p "${TSHDIR}/regress/fail"
	cat <<EOF >"${TSHDIR}/regress/fail/Makefile"
all:
	exit 1
EOF
	mkdir -p "${TSHDIR}/regress/hello"
	cat <<EOF >"${TSHDIR}/regress/hello/Makefile"
all:
	echo hello >${TSHDIR}/hello
EOF

	if ! PATH="${BINDIR}:${PATH}" sh "$ROBSDREGRESS" >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	assert_file - "${TSHDIR}/hello" <<-EOF
	hello
	EOF
fi
