export WRKDIR
utility_setup >"$TMP1"; read -r WRKDIR BUILDDIR <"$TMP1"

ROBSDREGRESS="${EXECDIR}/robsd-regress"

if testcase "basic"; then
	config_stub - "robsd-regress" <<-EOF
	REGRESSUSER=nobody
	TESTS=hello
	EOF
	mkdir "$BUILDDIR"
	mkdir -p "${TSHDIR}/regress/hello"
	cat <<EOF >"${TSHDIR}/regress/hello/Makefile"
all:
	echo hello >${TSHDIR}/hello
EOF

	if ! sh "$ROBSDREGRESS" >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	assert_file - "${TSHDIR}/hello" <<-EOF
	hello
	EOF
fi