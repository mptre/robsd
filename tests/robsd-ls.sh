# robsd_ls [-e] [-] -- [robsd-step-argument ...]
robsd_ls() {
	local _err0=0
	local _err1=0
	local _stdin="${TSHDIR}/stdin"
	local _stdout="${TSHDIR}/stdout"

	while [ $# -gt 0 ]; do
		case "$1" in
		-e)	_err0="1";;
		-)	cat >"$_stdin";;
		*)	break;;
		esac
		shift
	done
	[ "${1:-}" = "--" ] && shift

	${EXEC:-} "$ROBSDLS" -f "$ROBSDCONF" "$@" >"$_stdout" 2>&1 || _err1="$?"
	if [ "$_err0" -ne "$_err1" ]; then
		fail - "expected exit ${_err0}, got ${_err1}" <"$_stdout"
		return 0
	fi
	if [ -s "$_stdin" ]; then
		assert_file "$_stdin" "$_stdout"
	else
		cat "$_stdout"
	fi
}

if testcase "robsd"; then
	mkdir "${TSHDIR}/2022-11-28" "${TSHDIR}/2022-11-29"
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	robsd_ls - -- -m robsd <<-EOF
	${TSHDIR}/2022-11-29
	${TSHDIR}/2022-11-28
	EOF
fi

if testcase "cross"; then
	mkdir "${TSHDIR}/2022-11-28" "${TSHDIR}/2022-11-29"
	robsd_config -C - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	robsd_ls - -- -m robsd-cross <<-EOF
	${TSHDIR}/2022-11-29
	${TSHDIR}/2022-11-28
	EOF
fi

if testcase "ports"; then
	mkdir "${TSHDIR}/2022-11-28" "${TSHDIR}/2022-11-29"
	robsd_config -P - <<-EOF
	robsddir "${TSHDIR}"
	ports {}
	EOF
	robsd_ls - -- -m robsd-ports <<-EOF
	${TSHDIR}/2022-11-29
	${TSHDIR}/2022-11-28
	EOF
fi

if testcase "regress"; then
	mkdir "${TSHDIR}/2022-11-28" "${TSHDIR}/2022-11-29"
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "test"
	EOF
	robsd_ls - -- -m robsd-regress <<-EOF
	${TSHDIR}/2022-11-29
	${TSHDIR}/2022-11-28
	EOF
fi

if testcase "keep dir"; then
	mkdir "${TSHDIR}/2022-11-28" "${TSHDIR}/2022-11-29"
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	robsd_ls - -- -m robsd <<-EOF
	${TSHDIR}/2022-11-29
	${TSHDIR}/2022-11-28
	EOF
fi

if testcase "skip build dir"; then
	mkdir "${TSHDIR}/2022-11-28" "${TSHDIR}/2022-11-29"
	echo "${TSHDIR}/2022-11-29" >"${TSHDIR}/.running"
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	robsd_ls - -- -m robsd -B <<-EOF
	${TSHDIR}/2022-11-28
	EOF
fi

if testcase "skip build dir not running"; then
	mkdir "${TSHDIR}/2022-11-28" "${TSHDIR}/2022-11-29"
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	robsd_ls - -- -m robsd -B <<-EOF
	${TSHDIR}/2022-11-29
	${TSHDIR}/2022-11-28
	EOF
fi

if testcase "invalid missing mode"; then
	robsd_ls -e >"$TMP1"
	if ! grep -q usage "$TMP1"; then
		fail - "expected usage" <"$TMP1"
	fi
fi
