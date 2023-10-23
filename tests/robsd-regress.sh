portable no

robsd_mock >"$TMP1"; read -r _ BINDIR ROBSDDIR <"$TMP1"

ROBSDREGRESS="${EXECDIR}/robsd-regress"
ROBSDKILL="${EXECDIR}/robsd-kill"

if testcase "basic"; then
	robsd_config -R - <<-EOF
	robsddir "${ROBSDDIR}"
	regress "test/fail"
	regress "test/hello" obj { "usr.bin/hello" }
	regress "test/root" no-parallel root
	regress "test/env" env { "FOO=1" "BAR=2" }
	regress "test/pkg" packages { "quirks" "not-installed" }
	regress "test/targets" targets { "one" "two" }
	regress "test/xpass"
	EOF
	mkdir "$ROBSDDIR"
	mkdir -p "${TSHDIR}/regress/test/fail"
	cat <<EOF >"${TSHDIR}/regress/test/fail/Makefile"
regress:
	exit 66
obj:
EOF
	mkdir -p "${TSHDIR}/usr.bin/hello"
	cat <<EOF >"${TSHDIR}/usr.bin/hello/Makefile"
obj:
EOF
	mkdir -p "${TSHDIR}/regress/test/hello"
	cat <<EOF >"${TSHDIR}/regress/test/hello/Makefile"
regress:
	echo hello >${TSHDIR}/hello
obj:
EOF
	mkdir -p "${TSHDIR}/regress/test/root"
	cat <<EOF >"${TSHDIR}/regress/test/root/Makefile"
regress:
	echo SUDO=\${SUDO} >${TSHDIR}/root
obj:
EOF
	mkdir -p "${TSHDIR}/regress/test/env"
	cat <<EOF >"${TSHDIR}/regress/test/env/Makefile"
regress:
	echo FOO=\${FOO} BAR=\${BAR} >${TSHDIR}/env
obj:
EOF
	mkdir -p "${TSHDIR}/regress/test/pkg"
	cat <<EOF >"${TSHDIR}/regress/test/pkg/Makefile"
regress:

obj:
EOF
	mkdir -p "${TSHDIR}/regress/test/targets"
	cat <<EOF >"${TSHDIR}/regress/test/targets/Makefile"
one:
	echo one >${TSHDIR}/targets-one
	exit 1

two:
	echo two >${TSHDIR}/targets-two

obj:
EOF
	mkdir -p "${TSHDIR}/regress/test/xpass"
	cat <<EOF >"${TSHDIR}/regress/test/xpass/Makefile"
regress:
	echo ==== test ====
	echo UNEXPECTED_PASS

obj:
EOF
	cat <<-EOF >"${BINDIR}/pkg_add"
	#!/bin/sh
	echo "pkg_add \${1}" >>${TSHDIR}/pkg
	# Simulate failure, must be ignored.
	exit 1
	EOF
	chmod u+x "${BINDIR}/pkg_add"

	cat <<-EOF >"${BINDIR}/pkg_delete"
	#!/bin/sh
	echo "pkg_delete \${1}" >>${TSHDIR}/pkg
	# Simulate failure, must be ignored.
	exit 1
	EOF
	chmod u+x "${BINDIR}/pkg_delete"

	if ! PATH="${BINDIR}:${PATH}" sh "$ROBSDREGRESS" -d >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	assert_file - "${TSHDIR}/hello" <<-EOF
	hello
	EOF
	assert_file - "${TSHDIR}/root" <<-EOF
	SUDO=
	EOF
	assert_file - "${TSHDIR}/env" <<-EOF
	FOO=1 BAR=2
	EOF
	assert_file - "${TSHDIR}/pkg" <<-EOF
	pkg_add not-installed
	pkg_delete not-installed
	pkg_delete -a
	EOF
	echo one | assert_file - "${TSHDIR}/targets-one"
	echo two | assert_file - "${TSHDIR}/targets-two"

	_builddir="$(find "${ROBSDDIR}" -type d -mindepth 1 -maxdepth 1)"
	_steps="$(step_path "$_builddir")"
	step_eval -n test/xpass "$_steps"
	if [ "$(step_value exit)" -ne 1 ]; then
		fail "expected test/xpass to exit non-zero"
	fi
	step_eval -n test/targets "$_steps"
	if [ "$(step_value exit)" -eq 0 ]; then
		fail "expected test/targets to exit non-zero"
	fi

	rm "${BINDIR}/pkg_add"
	rm "${BINDIR}/pkg_delete"
fi

if testcase "failure in non-test step"; then
	robsd_config -R - <<-EOF
	robsddir "${ROBSDDIR}"
	regress "test/nothing"
	EOF
	mkdir "$ROBSDDIR"
	# Make the env step fail.
	cat <<-EOF >"${BINDIR}/df"
	#!/bin/sh
	exit 1
	EOF
	chmod u+x "${BINDIR}/df"

	if PATH="${BINDIR}:${PATH}" sh "$ROBSDREGRESS" -d >"$TMP1" 2>&1; then
		fail - "expected exit non-zero" <"$TMP1"
	fi

	rm "${BINDIR}/df"
fi

if testcase "failure in non-test step, conflicting with test name"; then
	robsd_config -R - <<-EOF
	robsddir "${ROBSDDIR}"
	regress "usr.bin/patch"
	EOF
	mkdir "$ROBSDDIR"
	: >"${TSHDIR}/patch"

	if PATH="${BINDIR}:${PATH}" sh "$ROBSDREGRESS" \
	   -d -S "${TSHDIR}/patch" >"$TMP1" 2>&1; then
		fail - "expected exit non-zero" <"$TMP1"
	fi
fi

if testcase "kill"; then
	robsd_config -R - <<-EOF
	robsddir "${ROBSDDIR}"
	regress "test/sleep"
	EOF
	mkdir "$ROBSDDIR"
	mkdir -p "${TSHDIR}/regress/test/sleep"
	cat <<EOF >"${TSHDIR}/regress/test/sleep/Makefile"
regress:
	echo sleep >${TSHDIR}/sleep
	sleep 3600
obj:
EOF

	if ! PATH="${BINDIR}:${PATH}" sh "$ROBSDREGRESS" \
	   >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	until [ -e "${TSHDIR}/sleep" ]; do
		sleep .1
	done

	_robsdkill="${TSHDIR}/robsd-regress-kill"
	cp "$ROBSDKILL" "$_robsdkill"
	PATH="${BINDIR}:${PATH}" sh "$_robsdkill"
	while pgrep -q -f "${ROBSDREGRESS}$"; do
		sleep .1
	done

	echo sleep | assert_file - "${TSHDIR}/sleep"
	if [ -e "${ROBSDDIR}/.running" ]; then
		fail "expected lock to not be present"
	fi
fi
