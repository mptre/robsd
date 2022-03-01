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
	[ "${1:-}" == "--" ] && shift

	"$ROBSDHOOK" -m "$_mode" -f "$CONFIG" "$@" \
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
	robsddir "/var/empty"
	destdir "/var/empty"
	execdir "/var/empty"
	x11-srcdir "/var/empty"
	EOF
}

# default_ports_config
default_ports_config() {
	cat <<-EOF
	robsddir "${TSHDIR}"
	chroot "/var/empty"
	execdir "/var/empty"
	ports-user "nobody"
	ports { "devel/knfmt" "mail/mdsort" }
	EOF
}

# default_regress_config
default_regress_config() {
	cat <<-EOF
	robsddir "/var/empty"
	execdir "/var/empty"
	regress-user "nobody"
	regress { "bin/csh:R" "bin/ksh:RS" "bin/ls" }
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
	/var/empty extra
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

if testcase "invalid variable reserved"; then
	default_config >"$CONFIG"
	robsd_hook -e - -- -v robsddir=/var/empty <<-EOF
	robsd-hook: variable 'robsddir' cannot be defined
	EOF
fi

if testcase "invalid variable missing separator"; then
	default_config >"$CONFIG"
	robsd_hook -e - -- -v extra <<-EOF
	robsd-hook: missing variable separator: extra
	EOF
fi
