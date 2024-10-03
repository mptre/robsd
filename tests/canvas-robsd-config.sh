# robsd_config [-e]  [-N] [-] [-- robsd-config-argument ...]
robsd_config() {
	local _config="${CONFIG}"
	local _err0=0
	local _err1=0
	local _stdin=0
	local _stdout="${TSHDIR}/stdout"

	while [ $# -gt 0 ]; do
		case "$1" in
		-e)	_err0="1";;
		-N)	_config="";;
		-)	_stdin=1;;
		*)	break;;
		esac
		shift
	done
	[ "${1:-}" = "--" ] && shift

	[ -e "${CONFIG}" ] || : >"${CONFIG}"
	[ -e "${STDIN}" ] || : >"${STDIN}"

	${EXEC:-} "${ROBSDCONFIG}" -m canvas ${_config:+"-C${_config}"} "$@" - \
		<"${STDIN}" >"${_stdout}" 2>&1 || _err1="$?"
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

# default_canvas_config
default_canvas_config() {
	cat <<-EOF
	canvas-name "test"
	canvas-dir "${TSHDIR}"
	EOF
}

CONFIG="${TSHDIR}/robsd.conf"
STDIN="${TSHDIR}/stdin"

if testcase "basic"; then
	{
		default_canvas_config
		echo 'step "1" command { "true" }'
		echo 'step "2" command { "true" }'
		echo 'step "3" command { "true" }'
		echo 'step "4" command { "true" }'
		echo 'step "5" command { "true" }'
		echo 'step "6" command { "true" }'
		echo 'step "7" command { "true" }'
		echo 'step "8" command { "true" }'
		echo 'step "9" command { "true" }'
		echo 'step "10" command { "true" }'
		echo 'step "11" command { "true" }'
		echo 'step "12" command { "true" }'
		echo 'step "13" command { "true" }'
		echo 'step "14" command { "true" }'
		echo 'step "15" command { "true" }'
		echo 'step "16" command { "true" }'
	} >"${CONFIG}"
	robsd_config
fi

if testcase "invalid: no steps"; then
	default_canvas_config >"${CONFIG}"
	robsd_config -e - <<-EOF
	robsd-config: ${CONFIG}: mandatory variable 'step' missing
	EOF
fi

if testcase "invalid: step no command"; then
	{
		default_canvas_config
		echo 'step "first"'
	} >"${CONFIG}"
	robsd_config -e - <<-EOF
	robsd-config: ${CONFIG}:3: mandatory step option 'command' missing
	EOF
fi

if testcase "invalid: step empty command"; then
	{
		default_canvas_config
		echo 'step "first" command {}'
	} >"${CONFIG}"
	robsd_config -e - <<-EOF
	robsd-config: ${CONFIG}:3: mandatory step option 'command' missing
	EOF
fi

if testcase "invalid: interpolate step variable"; then
	{
		default_canvas_config
		echo 'step "first" command { "true" }'
	} >"${CONFIG}"
	echo "\${step}" >"${STDIN}"
	robsd_config -e - <<-EOF
	robsd-config: /dev/stdin:1: invalid substitution, unknown variable 'step'
	EOF
fi

if testcase "invalid: missing path"; then
	robsd_config -e -N - <<-EOF
	robsd-config: configuration file missing
	EOF
fi
