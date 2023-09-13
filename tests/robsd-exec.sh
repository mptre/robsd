setup() {
	cat <<-EOF >"${TSHDIR}/robsd-ok.sh"
	echo ok
	EOF
}

# robsd_exec [-- robsd-exec-argument ...]
robsd_exec() {
	local _err0=0
	local _err1=0
	local _mode="robsd"
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

	${EXEC:-} "$ROBSDEXEC" "$@" \
		>"$_stdout" 2>&1 || _err1="$?"
	if [ "$_err0" -ne "$_err1" ]; then
		fail - "expected exit ${_err0}, got ${_err1}" <"$_stdout"
		return 0
	fi
	if [ "$_stdin" -eq 1 ]; then
		assert_file - "$_stdout"
	else
		cat "$_stdout"
	fi
}

if testcase "robsd"; then
	robsd_exec - -- sh -eu "${TSHDIR}/robsd-ok.sh" <<-EOF
	ok
	EOF
fi
