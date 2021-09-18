utility_setup >"$TMP1"; read -r _ BINDIR ROBSDDIR <"$TMP1"

ROBSDREGRESS="${EXECDIR}/robsd-regress"

if testcase "basic"; then
	config_stub - "robsd-regress" <<-EOF
	ROBSDDIR=${ROBSDDIR}
	EXECDIR=${EXECDIR}
	REGRESSUSER=nobody
	SUDO=doas
	TESTS="fail hello:P root:R"
	EOF
	mkdir "$ROBSDDIR"
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
	mkdir -p "${TSHDIR}/regress/root"
	cat <<EOF >"${TSHDIR}/regress/root/Makefile"
all:
	echo SUDO=\${SUDO} >${TSHDIR}/root
EOF

	if ! PATH="${BINDIR}:${PATH}" sh "$ROBSDREGRESS" >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	assert_file - "${TSHDIR}/hello" <<-EOF
	hello
	EOF
	assert_file - "${TSHDIR}/root" <<-EOF
	SUDO=
	EOF
fi
