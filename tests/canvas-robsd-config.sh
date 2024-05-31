# robsd_config [-e] [-] [-- robsd-config-argument ...]
robsd_config() {
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

	[ -e "$CONFIG" ] || : >"$CONFIG"
	[ -e "$STDIN" ] || : >"$STDIN"

	${EXEC:-} "$ROBSDCONFIG" -m canvas -C "$CONFIG" "$@" - \
		<"$STDIN" >"$_stdout" 2>&1 || _err1="$?"
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
		echo 'step "first" command { "true" }'
	} >"$CONFIG"
	robsd_config
fi

if testcase "invalid: no steps"; then
	default_canvas_config >"$CONFIG"
	robsd_config -e - <<-EOF
	robsd-config: ${CONFIG}: mandatory variable 'step' missing
	EOF
fi

if testcase "invalid: step no command"; then
	{
		default_canvas_config
		echo 'step "first"'
	} >"$CONFIG"
	robsd_config -e - <<-EOF
	robsd-config: ${CONFIG}:3: mandatory step option 'command' missing
	EOF
fi

if testcase "invalid: step empty command"; then
	{
		default_canvas_config
		echo 'step "first" command {}'
	} >"$CONFIG"
	robsd_config -e - <<-EOF
	robsd-config: ${CONFIG}:3: mandatory step option 'command' missing
	EOF
fi

if testcase "invalid: interpolate step variable"; then
	{
		default_canvas_config
		echo 'step "first" command { "true" }'
	} >"$CONFIG"
	echo "\${step}" >"$STDIN"
	robsd_config -e - <<-EOF
	robsd-config: /dev/stdin:1: invalid substitution, unknown variable 'step'
	EOF
fi
