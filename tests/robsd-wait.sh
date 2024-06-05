portable no

# robsd_wait [-- robsd-wait-argument ...]
robsd_wait() {
	local _err0=0
	local _err1=0
	local _stdin="${TSHDIR}/stdin"
	local _stdout="${TSHDIR}/stdout"

	while [ $# -gt 0 ]; do
		case "$1" in
		-)	cat >"${_stdin}";;
		-e)	_err0=1;;
		*)	break;;
		esac
		shift
	done
	[ "${1:-}" = "--" ] && shift

	${EXEC:-} "${ROBSDWAIT}" "$@" >"${_stdout}" 2>&1 || _err1="$?"
	if [ "${_err0}" -ne "${_err1}" ]; then
		fail - "expected exit ${_err0}, got ${_err1}" <"${_stdout}"
		return 0
	fi
	if [ -e "${_stdin}" ]; then
		assert_file "${_stdin}" "${_stdout}"
	else
		cat "${_stdout}"
	fi
}

if testcase "basic"; then
	_p0="$$"
	env true &
	_p1="$!"
	robsd_wait - -- "${_p0}" "${_p1}" <<-EOF
	${_p0}
	EOF
fi

if testcase "all"; then
	env sleep 0.1 & _p0="$!"
	env sleep 0.1 & _p1="$!"
	env sleep 0.1 & _p2="$!"
	env sleep 0.1 & _p3="$!"
	env sleep 0.1 & _p4="$!"

	robsd_wait - -- -a "${_p0}" "${_p1}" "${_p2}" "${_p3}" "${_p4}" </dev/null
fi

if testcase "process not found"; then
	robsd_wait - -- 2147483647 </dev/null
fi

if testcase "invalid: no arguments"; then
	robsd_wait -e >"${TMP1}"
	if ! grep -q usage "${TMP1}"; then
		fail - "expected usage" <"${TMP1}"
	fi
fi

if testcase "invalid: pid"; then
	robsd_wait -e - -- nein <<-EOF
	robsd-wait: nein invalid
	EOF
fi
