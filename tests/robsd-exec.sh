setup() {
	export EXECDIR="$TSHDIR"

	mkdir "${TSHDIR}/.conf"

	robsd_config - <<-EOF
	robsddir "$TSHDIR"
	EOF
	mv "$ROBSDCONF" "${TSHDIR}/.conf/robsd.conf"

	robsd_config -C - <<-EOF
	robsddir "$TSHDIR"
	EOF
	mv "$ROBSDCONF" "${TSHDIR}/.conf/robsd-cross.conf"

	robsd_config -P - <<-EOF
	robsddir "$TSHDIR"
	ports { "devel/robsd" }
	EOF
	mv "$ROBSDCONF" "${TSHDIR}/.conf/robsd-ports.conf"

	robsd_config -R - <<-EOF
	robsddir "$TSHDIR"
	regress "test/one"
	EOF
	mv "$ROBSDCONF" "${TSHDIR}/.conf/robsd-regress.conf"
}


# robsd_exec -m mode [-e] [-] [-- robsd-exec-argument ...]
robsd_exec() {
	local _err0=0
	local _err1=0
	local _mode="robsd"
	local _stdin=0
	local _stdout="${TSHDIR}/stdout"

	while [ $# -gt 0 ]; do
		case "$1" in
		-e)	_err0="1";;
		-m)	shift; _mode="$1";;
		-)	_stdin=1;;
		*)	break;;
		esac
		shift
	done
	[ "${1:-}" = "--" ] && shift

	${EXEC:-} "$ROBSDEXEC" \
		-m "$_mode" -C "${TSHDIR}/.conf/${_mode}.conf" "$@" \
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
	cat <<-EOF >"${TSHDIR}/robsd-test.sh"
	echo robsd
	EOF

	robsd_exec -m robsd - -- test <<-EOF
	robsd
	EOF
fi

if testcase "robsd-cross"; then
	cat <<-EOF >"${TSHDIR}/robsd-cross-test.sh"
	echo robsd-cross
	EOF

	robsd_exec -m robsd-cross - -- test <<-EOF
	robsd-cross
	EOF
fi

if testcase "robsd-regress"; then
	cat <<-'EOF' >"${TSHDIR}/robsd-regress-exec.sh"
	echo robsd-regress: ${*}
	EOF

	robsd_exec -m robsd-regress - -- test <<-EOF
	robsd-regress: test
	EOF
fi

if testcase "trace"; then
	cat <<-'EOF' >"${TSHDIR}/robsd-test.sh"
	:
	EOF

	robsd_exec -m robsd - -- -x test <<-EOF
	+ :
	EOF
fi

if testcase "invalid: step script not found"; then
	robsd_exec -e -m robsd - -- nein <<-EOF
	robsd-exec: nein: step script not found
	EOF
fi
