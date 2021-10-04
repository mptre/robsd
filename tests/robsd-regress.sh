utility_setup >"$TMP1"; read -r _ BINDIR ROBSDDIR <"$TMP1"

ROBSDREGRESS="${EXECDIR}/robsd-regress"

if testcase "basic"; then
	config_stub - "robsd-regress" <<-EOF
	ROBSDDIR=${ROBSDDIR}
	EXECDIR=${EXECDIR}
	REGRESSUSER=nobody
	SUDO=doas
	TESTS="test/fail test/hello:P test/root:R"
	EOF
	mkdir "$ROBSDDIR"
	mkdir -p "${TSHDIR}/regress/test/fail"
	cat <<EOF >"${TSHDIR}/regress/test/fail/Makefile"
all:
	exit 1
EOF
	mkdir -p "${TSHDIR}/regress/test/hello"
	cat <<EOF >"${TSHDIR}/regress/test/hello/Makefile"
all:
	echo hello >${TSHDIR}/hello
EOF
	mkdir -p "${TSHDIR}/regress/test/root"
	cat <<EOF >"${TSHDIR}/regress/test/root/Makefile"
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

if testcase "failure in non-test step"; then
	config_stub - "robsd-regress" <<-EOF
	ROBSDDIR=${ROBSDDIR}
	EXECDIR=${EXECDIR}
	REGRESSUSER=nobody
	TESTS="test/nothing"
	EOF
	mkdir "$ROBSDDIR"
	# Make the env step fail.
	cat <<-EOF >"${BINDIR}/df"
	#!/bin/sh
	exit 1
	EOF
	chmod u+x "${BINDIR}/df"

	if PATH="${BINDIR}:${PATH}" sh "$ROBSDREGRESS" >"$TMP1" 2>&1; then
		fail - "expected exit non-zero" <"$TMP1"
	fi
fi
