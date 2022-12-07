# robsd_hook [-- robsd-hook-argument ...]
robsd_hook() {
	local _err0=0
	local _err1=0
	local _mode="robsd"
	local _stdin=0
	local _stdout="${TSHDIR}/stdout"

	while [ $# -gt 0 ]; do
		case "$1" in
		-P)	_mode="robsd-ports";;
		-R)	_mode="robsd-regress";;
		-e)	_err0="1";;
		-)	_stdin=1;;
		*)	break;;
		esac
		shift
	done
	[ "${1:-}" = "--" ] && shift

	${EXEC:-} "$ROBSDHOOK" -m "$_mode" -f "$CONFIG" "$@" \
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

# default_config
default_config() {
	cat <<-EOF
	robsddir "/tmp"
	destdir "/tmp"
	execdir "/tmp"
	bsd-objdir "/tmp"
	bsd-srcdir "/tmp"
	x11-objdir "/tmp"
	x11-srcdir "/tmp"
	EOF
}

# default_ports_config
default_ports_config() {
	cat <<-EOF
	robsddir "${TSHDIR}"
	chroot "/tmp"
	execdir "/tmp"
	ports-user "nobody"
	ports { "devel/knfmt" "mail/mdsort" }
	EOF
}

# default_regress_config
default_regress_config() {
	cat <<-EOF
	robsddir "/tmp"
	execdir "/tmp"
	regress "bin/csh" root
	regress "bin/ksh" root quiet
	regress "bin/ls"
	EOF
}

CONFIG="${TSHDIR}/robsd.conf"

if testcase "robsd"; then
	{ echo "hook { \"echo\" \"\${reboot}\" \"\${extra}\" }";
	  default_config; } >"$CONFIG"
	robsd_hook - -- -v extra=extra <<-EOF
	0 extra
	EOF
fi

if testcase "robsd-ports"; then
	{ echo "hook { \"echo\" \"\${chroot}\" \"\${extra}\" }";
	  default_ports_config; } >"$CONFIG"
	robsd_hook -P - -- -v extra=extra <<-EOF
	/tmp extra
	EOF
fi

if testcase "robsd-regress"; then
	{ echo "hook { \"echo\" \"\${rdonly}\" \"\${extra}\" }";
	  default_regress_config; } >"$CONFIG"
	robsd_hook -R - -- -v extra=extra <<-EOF
	0 extra
	EOF
fi

if testcase "hook not defined"; then
	default_config >"$CONFIG"
	robsd_hook - </dev/null
fi

if testcase "verbose"; then
	{ echo "hook { \"true\" }"; default_config; } >"$CONFIG"
	robsd_hook - -- -V <<-EOF
	robsd-hook: exec "true"
	EOF
fi

if testcase "invalid: variable reserved"; then
	default_config >"$CONFIG"
	robsd_hook -e - -- -v robsddir=/tmp <<-EOF
	robsd-hook: variable 'robsddir' cannot be defined
	EOF
fi

if testcase "invalid: variable missing separator"; then
	default_config >"$CONFIG"
	robsd_hook -e - -- -v extra <<-EOF
	robsd-hook: missing variable separator in 'extra'
	EOF
fi

if testcase "invalid: interpolation"; then
	{ echo "hook { \"\${nein}\" }"; default_config; } >"$CONFIG"
	robsd_hook -e - <<-EOF
	robsd-hook: invalid substitution, unknown variable 'nein'
	EOF
fi

if testcase "invalid: arguments"; then
	default_config >"$CONFIG"
	robsd_hook -e -- -nein >/dev/null
fi
