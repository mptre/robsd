# robsd_config [-CPRe] [-] [-- robsd-config-argument ...]
robsd_config() {
	local _err0=0
	local _err1=0
	local _mode="robsd"
	local _stdin=0
	local _stdout="${TSHDIR}/stdout"

	while [ $# -gt 0 ]; do
		case "$1" in
		-C)	_mode="robsd-cross";;
		-P)	_mode="robsd-ports";;
		-R)	_mode="robsd-regress";;
		-e)	_err0="1";;
		-)	_stdin=1;;
		*)	break;;
		esac
		shift
	done
	[ "${1:-}" == "--" ] && shift

	[ -e "$CONFIG" ] || : >"$CONFIG"
	[ -e "$STDIN" ] || : >"$STDIN"

	"$ROBSDCONFIG" -m "$_mode" -f "$CONFIG" "$@" - \
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

# default_config
default_config() {
	cat <<-EOF
	robsddir "/var/empty"
	destdir "/var/empty"
	execdir "/var/empty"
	bsd-objdir "/var/empty"
	bsd-srcdir "/var/empty"
	x11-objdir "/var/empty"
	x11-srcdir "/var/empty"
	EOF
}

# default_cross_config
default_cross_config() {
	cat <<-EOF
	robsddir "${TSHDIR}"
	crossdir "/var/empty"
	execdir "/var/empty"
	bsd-objdir "/var/empty"
	bsd-srcdir "/var/empty"
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
	bsd-srcdir "/var/empty"
	regress-user "nobody"
	regress { "bin/csh:R" "bin/ksh:RS" "bin/ls" }
	EOF
}

CONFIG="${TSHDIR}/robsd.conf"
STDIN="${TSHDIR}/stdin"

if testcase "robsd"; then
	default_config >"$CONFIG"
	robsd_config
fi

if testcase "cross"; then
	default_cross_config >"$CONFIG"
	echo "CROSSDIR=\${crossdir}" >"$STDIN"
	robsd_config -C - <<-EOF
	CROSSDIR=/var/empty
	EOF
fi

if testcase "cross target"; then
	echo 'target "am64"' >"$CONFIG"
	robsd_config -C -e - <<-EOF
	robsd-config: ${CONFIG}:1: variable cannot be defined
	EOF
fi

if testcase "ports"; then
	default_ports_config >"$CONFIG"
	echo "PORTS=\${ports}" >"$STDIN"
	robsd_config -P - <<-EOF
	PORTS=devel/knfmt mail/mdsort
	EOF
fi

if testcase "regress"; then
	default_regress_config >"$CONFIG"
	echo "REGRESS=\${regress}" >"$STDIN"
	robsd_config -R - <<-EOF
	REGRESS=bin/csh bin/ksh bin/ls
	EOF
fi

if testcase "regress pseudo"; then
	default_regress_config >"$CONFIG"
	echo "ROOT=\${regress-root}" >"$STDIN"
	robsd_config -R - <<-EOF
	ROOT=bin/csh bin/ksh
	EOF
fi

if testcase "regress pseudo invalid flags"; then
	echo 'regress { "bin/csh:A" }' >"$CONFIG"
	robsd_config -R -e | grep -e flag >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	robsd-config: ${CONFIG}:1: unknown regress flag 'A'
	EOF
fi

if testcase "regress pseudo empty flags"; then
	echo 'regress { "bin/csh:" }' >"$CONFIG"
	robsd_config -R -e | grep -e flags >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	robsd-config: ${CONFIG}:1: empty regress flags
	EOF
fi

if testcase "boolean yes"; then
	{ default_regress_config; echo 'rdonly yes'; } >"$CONFIG"
	echo "RDONLY=\${rdonly}" >"$STDIN"
	robsd_config -R - <<-EOF
	RDONLY=1
	EOF
fi

if testcase "boolean no"; then
	{ default_regress_config; echo 'rdonly no'; } >"$CONFIG"
	echo "RDONLY=\${rdonly}" >"$STDIN"
	robsd_config -R - <<-EOF
	RDONLY=0
	EOF
fi

if testcase "boolean default value"; then
	default_regress_config >"$CONFIG"
	echo "RDONLY=\${rdonly}" >"$STDIN"
	robsd_config -R - <<-EOF
	RDONLY=0
	EOF
fi

if testcase "integer default value"; then
	default_config >"$CONFIG"
	echo "KEEP=\${keep}" >"$STDIN"
	robsd_config - <<-EOF
	KEEP=0
	EOF
fi

if testcase "string default value"; then
	default_config >"$CONFIG"
	echo "STRING=\${distrib-host}" >"$STDIN"
	robsd_config - <<-EOF
	STRING=
	EOF
fi

if testcase "string interpolation"; then
	{
		default_config
		echo "kernel \"\${robsddir}\""
	} >"$CONFIG"
	echo "\${kernel}" >"$STDIN"
	robsd_config - <<-EOF
	/var/empty
	EOF
fi

if testcase "list default value"; then
	default_config >"$CONFIG"
	echo "SKIP=\${skip}" >"$STDIN"
	robsd_config - <<-EOF
	SKIP=
	EOF
fi

if testcase "list interpolation"; then
	{
		default_config
		echo "skip { \"ROBSDDIR=\${robsddir}\" }"
	} >"$CONFIG"
	echo "\${skip}" >"$STDIN"
	robsd_config - <<-EOF
	ROBSDDIR=/var/empty
	EOF
fi

if testcase "hook"; then
	{
		default_config
		echo "hook { \"echo\" \"\${robsddir}\" }"
	} >"$CONFIG"
	echo "\${hook}" >"$STDIN"
	robsd_config - <<-'EOF'
	echo /var/empty
	EOF
fi

if testcase "comment"; then
	{
		default_config
		echo "# comment"
		echo "keep 0 # comment"
	} >"$CONFIG"
	echo "KEEP=\${keep}" >"$STDIN"
	robsd_config - <<-EOF
	KEEP=0
	EOF
fi

if testcase "invalid missing file"; then
	robsd_config -e -- -f /nein >/dev/null
fi

if testcase "invalid grammar"; then
	cat <<-EOF >"$CONFIG"
	FOO=bar
	EOF
	robsd_config -e | head -1 >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	robsd-config: ${CONFIG}:1: want KEYWORD, got UNKNOWN
	EOF
fi

if testcase "invalid directory missing"; then
	{
		default_config | sed -e '/bsd-objdir/d'
		echo 'bsd-objdir "/nein"'
	} >"$CONFIG"
	robsd_config -e - <<-EOF
	robsd-config: ${CONFIG}:7: /nein: No such file or directory
	EOF
fi

if testcase "invalid not a directory"; then
	{
		printf 'bsd-objdir "%s"\n' "$CONFIG"
		default_config | sed -e '/bsd-objdir/d'
	} >"$CONFIG"
	robsd_config -e - <<-EOF
	robsd-config: ${CONFIG}:1: ${CONFIG}: is not a directory
	EOF
fi

if testcase "invalid already defined"; then
	{ default_config; echo 'robsddir "/var/empty"'; } >"$CONFIG"
	robsd_config -e - <<-EOF
	robsd-config: ${CONFIG}:8: variable 'robsddir' already defined
	EOF
fi

if testcase "invalid missing mandatory"; then
	robsd_config -e | grep -e mandatory >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	robsd-config: ${CONFIG}: mandatory variable 'robsddir' missing
	robsd-config: ${CONFIG}: mandatory variable 'destdir' missing
	EOF
fi

if testcase "invalid empty mandatory"; then
	{
		printf 'robsddir ""\n'
		default_config | sed -e '/robsddir/d'
	} >"$CONFIG"
	robsd_config -e | grep -v -e mandatory >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	robsd-config: ${CONFIG}:1: empty string
	EOF
fi

if testcase "invalid variable value"; then
	cat <<-EOF >"$CONFIG"
	bsd-objdir 1
	bsd-srcdir 1
	EOF
	robsd_config -e | grep -v -e mandatory >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	robsd-config: ${CONFIG}:1: want STRING, got INTEGER
	robsd-config: ${CONFIG}:2: want STRING, got INTEGER
	EOF
fi

if testcase "invalid keyword"; then
	cat <<-EOF >"$CONFIG"
	one 1
	two 2
	EOF
	robsd_config -e | grep -v -e mandatory >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	robsd-config: ${CONFIG}:1: unknown keyword 'one'
	EOF
fi

if testcase "invalid integer overflow"; then
	cat <<-EOF >"$CONFIG"
	keep 1111111111111111111111111111111111111111
	EOF
	robsd_config -e | head -1 >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	robsd-config: ${CONFIG}:1: integer too big
	EOF
fi

if testcase "invalid user"; then
	cat <<-EOF >"$CONFIG"
	cvs-user "unknown"
	EOF
	robsd_config -e | grep -v -e mandatory >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	robsd-config: ${CONFIG}:1: user 'unknown' not found
	EOF
fi

if testcase "invalid template missing {"; then
	default_config >"$CONFIG"
	cat <<-'EOF' >"$STDIN"
	FOO=$
	EOF
	robsd_config -e - <<-EOF
	robsd-config: /dev/stdin:1: invalid substitution, expected '{'
	EOF
fi

if testcase "invalid template missing }"; then
	default_config >"$CONFIG"
	cat <<-'EOF' >"$STDIN"
	FOO=${
	EOF
	robsd_config -e - <<-EOF
	robsd-config: /dev/stdin:1: invalid substitution, expected '}'
	EOF
fi

if testcase "invalid template empty variable name"; then
	default_config >"$CONFIG"
	cat <<-'EOF' >"$STDIN"
	FOO=${}
	EOF
	robsd_config -e - <<-EOF
	robsd-config: /dev/stdin:1: invalid substitution, empty variable name
	EOF
fi

if testcase "invalid template unknown variable name"; then
	default_config >"$CONFIG"
	cat <<-'EOF' >"$STDIN"
	FOO=${foo}
	EOF
	robsd_config -e - <<-EOF
	robsd-config: /dev/stdin:1: invalid substitution, unknown variable 'foo'
	EOF
fi
