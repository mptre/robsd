portable no

robsd_mock >"${TMP1}"; read -r _ BINDIR _ <"${TMP1}"

# robsd_clean [-e] [-- robsd-clean-argument ...]
robsd_clean() {
	local _err0=0
	local _err1=0
	local _stdin=0
	local _stdout="${TSHDIR}/stdout"

	while [ $# -gt 0 ]; do
		case "$1" in
		-e)	_err0="1";;
		-)	_stdin=1;;
		*)	break;;
		esac
		shift
	done
	[ "${1:-}" = "--" ] && shift

	env "PATH=${BINDIR}:${PATH}" sh "${EXECDIR}/robsd-clean" \
		${ROBSDCONF:+"-C${ROBSDCONF}"} "$@" \
		>"${_stdout}" 2>&1 || _err1="$?"
	if [ "${_err0}" -ne "${_err1}" ]; then
		fail - "expected exit ${_err0}, got ${_err1}" <"${_stdout}"
		return 0
	fi
	if [ "${_stdin}" -eq 1 ]; then
		assert_file - "${_stdout}"
	else
		cat "${_stdout}"
	fi
}

setup() {
	unset ROBSDCONF
}

if testcase "count argument"; then
	echo "echo 0" >"${BINDIR}/id"
	chmod u+x "${BINDIR}/id"

	robsd_config - <<-EOF
	robsddir "${TSHDIR}/robsd"
	EOF
	mkdir -p "${TSHDIR}/robsd/2024-06-07."{1,2,3}
	echo "${TSHDIR}/robsd/2024-06-07.3" >"${TSHDIR}/robsd/.running"

	robsd_clean - -- -m robsd 1 <<-EOF
	robsd-clean: moving ${TSHDIR}/robsd/2024-06-07.2 to ${TSHDIR}/robsd/attic
	robsd-clean: moving ${TSHDIR}/robsd/2024-06-07.1 to ${TSHDIR}/robsd/attic
	EOF
fi

if testcase "no count argument"; then
	echo "echo 0" >"${BINDIR}/id"
	chmod u+x "${BINDIR}/id"

	robsd_config - <<-EOF
	robsddir "${TSHDIR}/robsd"
	keep 2
	EOF
	mkdir -p "${TSHDIR}/robsd/2024-06-07."{1,2,3}
	echo "${TSHDIR}/robsd/2024-06-07.3" >"${TSHDIR}/robsd/.running"

	robsd_clean - -- -m robsd <<-EOF
	robsd-clean: moving ${TSHDIR}/robsd/2024-06-07.1 to ${TSHDIR}/robsd/attic
	EOF
fi

if testcase "no attic"; then
	echo "echo 0" >"${BINDIR}/id"
	chmod u+x "${BINDIR}/id"

	robsd_config - <<-EOF
	robsddir "${TSHDIR}/robsd"
	keep 2
	keep-attic no
	EOF
	mkdir -p "${TSHDIR}/robsd/2024-06-07."{1,2,3}
	echo "${TSHDIR}/robsd/2024-06-07.3" >"${TSHDIR}/robsd/.running"

	robsd_clean - -- -m robsd <<-EOF
	robsd-clean: removing ${TSHDIR}/robsd/2024-06-07.1
	EOF

	ls "${TSHDIR}/robsd" >"${TMP1}"
	assert_file - "${TMP1}" <<-EOF
	2024-06-07.2
	2024-06-07.3
	EOF
fi

if testcase "robsd: requires root"; then
	echo "echo 1337" >"${BINDIR}/id"
	chmod u+x "${BINDIR}/id"

	robsd_config

	robsd_clean -e - -- -m robsd 1000 <<-EOF
	robsd-clean: must be run as root
	EOF
fi

if testcase "canvas: does not require root"; then
	echo "echo 1337" >"${BINDIR}/id"
	chmod u+x "${BINDIR}/id"

	robsd_config -c - <<-EOF
	canvas-dir "${TSHDIR}"
	step "test" command { "true" }
	EOF

	robsd_clean - -- -m canvas 1000 <<-EOF
	EOF
fi

if testcase "canvas: requires configuration"; then
	robsd_clean -e -- -m canvas 1000 >"${TMP1}"
	if ! grep -q usage "${TMP1}"; then
		fail - "expected usage" <"${TMP1}"
	fi
fi
