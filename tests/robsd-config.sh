# shellcheck disable=SC2016

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
	[ "${1:-}" = "--" ] && shift

	[ -e "${CONFIG}" ] || : >"${CONFIG}"
	[ -e "${STDIN}" ] || : >"${STDIN}"

	${EXEC:-} "${ROBSDCONFIG}" -m "${_mode}" -C "${CONFIG}" "$@" - \
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

# default_config
default_config() {
	cat <<-EOF
	robsddir "${TSHDIR}"
	destdir "/tmp"
	bsd-objdir "/tmp"
	bsd-srcdir "/tmp"
	x11-objdir "/tmp"
	x11-srcdir "/tmp"
	EOF
}

# default_cross_config
default_cross_config() {
	cat <<-EOF
	robsddir "${TSHDIR}"
	crossdir "/tmp"
	bsd-srcdir "/tmp"
	EOF
}

# default_ports_config
default_ports_config() {
	cat <<-EOF
	robsddir "${TSHDIR}"
	chroot "/tmp"
	ports-user "nobody"
	ports { "devel/knfmt" "mail/mdsort" }
	EOF
}

# default_regress_config
default_regress_config() {
	cat <<-EOF
	robsddir "/tmp"
	bsd-srcdir "/tmp"
	regress "bin/csh" root
	regress "bin/ksh" root quiet
	regress "bin/ls"
	EOF
}

CONFIG="${TSHDIR}/robsd.conf"
STDIN="${TSHDIR}/stdin"

if testcase "robsd"; then
	default_config >"${CONFIG}"
	robsd_config
fi

if testcase "cross"; then
	default_cross_config >"${CONFIG}"
	echo "CROSSDIR=\${crossdir}" >"${STDIN}"
	robsd_config -C - <<-EOF
	CROSSDIR=/tmp
	EOF
fi

if testcase "ports"; then
	default_ports_config >"${CONFIG}"
	echo "PORTS=\${ports}" >"${STDIN}"
	robsd_config -P - <<-EOF
	PORTS=devel/knfmt mail/mdsort
	EOF
fi

if testcase "regress"; then
	default_regress_config >"${CONFIG}"
	{
		echo "REGRESS=\${regress}"
		echo "USER=\${regress-user}"
	} >"${STDIN}"
	robsd_config -R - <<-EOF
	REGRESS=bin/csh bin/ksh bin/ls
	USER=build
	EOF
fi

if testcase "regress env"; then
	{
		default_regress_config
		echo 'regress-env { "GLOBAL1=1" }'
		echo 'regress "env" env { "FOO=1" "BAR=2" }'
		echo 'regress-env { "GLOBAL2=2" }'
	} >"${CONFIG}"
	echo "\${regress-env-env}" >"${STDIN}"
	robsd_config -R - <<-EOF
	GLOBAL1=1 GLOBAL2=2 FOO=1 BAR=2
	EOF
fi

if testcase "regress env missing"; then
	{
		default_regress_config
		echo 'regress "env"'
		echo 'regress-env { "GLOBAL1=1" }'
	} >"${CONFIG}"
	echo "\${regress-env-env}" >"${STDIN}"
	robsd_config -R - <<-EOF
	GLOBAL1=1
	EOF
fi

if testcase "regress obj"; then
	default_regress_config >"${CONFIG}"
	echo "OBJ=\${regress-obj}" >"${STDIN}"
	robsd_config -R -e - <<-EOF
	robsd-config: /dev/stdin:1: invalid substitution, unknown variable 'regress-obj'
	EOF

	{
		default_regress_config
		echo 'regress "obj" obj { "one" "two" }'
	} >"${CONFIG}"
	robsd_config -R - <<-EOF
	OBJ=one two
	EOF
fi

if testcase "regress root"; then
	default_regress_config >"${CONFIG}"
	echo "\${regress-bin/csh-root} \${regress-bin/ksh-root}" >"${STDIN}"
	robsd_config -R - <<-EOF
	1 1
	EOF
fi

if testcase "regress quiet"; then
	default_regress_config >"${CONFIG}"
	echo "\${regress-bin/ksh-quiet}" >"${STDIN}"
	robsd_config -R - <<-EOF
	1
	EOF
fi

if testcase "regress packages"; then
	{
		default_regress_config
		echo 'regress "test" packages { "knfmt" "mdsort" }'
	} >"${CONFIG}"
	echo "\${regress-packages}" >"${STDIN}"
	robsd_config -R - <<-EOF
	knfmt mdsort
	EOF
fi

if testcase "regress parallel"; then
	{
		default_regress_config
		echo 'regress "true"'
		echo 'regress "false" no-parallel'
	} >"${CONFIG}"
	{
		echo -n "\${regress-true-parallel} "
		echo -n "\${regress-false-parallel} "
		echo "\${regress-nein-parallel}"
	} >"${STDIN}"
	robsd_config -R - <<-EOF
	1 0 1
	EOF
fi

if testcase "regress parallel disabled"; then
	{
		default_regress_config
		echo 'parallel no'
		echo 'regress "false" no-parallel'
		echo 'regress "true"'
	} >"${CONFIG}"
	{
		echo "\${regress-true-parallel} \${regress-false-parallel}"
	} >"${STDIN}"
	robsd_config -R - <<-EOF
	0 0
	EOF
fi

if testcase "regress targets"; then
	{
		default_regress_config
		echo 'regress "test" targets { "one" "two" }'
	} >"${CONFIG}"
	echo "\${regress-test-targets} \${regress-bin/ksh-targets}" >"${STDIN}"
	robsd_config -R - <<-EOF
	one two regress
	EOF
fi

if testcase "regress interpolation inet"; then
	default_regress_config >"${CONFIG}"
	echo "\${inet}" >"${STDIN}"
	robsd_config -R >/dev/null
fi

if testcase "regress long name"; then
	_name="$(awk 'END {while (i++ < 256) printf("r")}' </dev/null)"
	{
		default_regress_config
		printf 'regress "%s" root\n' "${_name}"
	} >"${CONFIG}"
	echo "\${regress-${_name}-root}" >"${STDIN}"
	robsd_config -R - <<-EOF
	1
	EOF
fi

if testcase "regress rdomain w/o regress-env"; then
	{
		default_regress_config
		printf 'regress "foo" env { "${rdomain} ${rdomain}" }\n'
		printf 'regress "bar"\n'
		printf 'regress "baz" env { "${rdomain} ${rdomain}" }\n'
	} >"${CONFIG}"
	echo "\${regress-foo-env},\${regress-baz-env}" >"${STDIN}"
	robsd_config -R - <<-EOF
	 11 12, 13 14
	EOF
fi

if testcase "regress rdomain w/ regress-env"; then
	{
		default_regress_config
		printf 'regress-env { "FOO=1" }\n'
		printf 'regress "foo" env { "${rdomain} ${rdomain}" }\n'
		printf 'regress "bar"\n'
		printf 'regress "baz" env { "${rdomain} ${rdomain}" }\n'
	} >"${CONFIG}"
	echo "\${regress-foo-env},\${regress-baz-env}" >"${STDIN}"
	robsd_config -R - <<-EOF
	FOO=1 11 12,FOO=1 13 14
	EOF
fi

if testcase "regress rdomain in regress-env"; then
	{
		default_regress_config
		printf 'regress-env { "${rdomain}" }\n'
		printf 'regress "foo" env { "${rdomain}" }\n'
	} >"${CONFIG}"
	echo "\${regress-bin/ls-env},\${regress-bin/ls-env},\${regress-foo-env}" >"${STDIN}"
	robsd_config -R - <<-EOF
	12,13,14 11
	EOF
fi

if testcase "regress rdomain wrap around"; then
	{
		default_regress_config
		printf 'regress-env { "${rdomain}" }\n'
	} >"${CONFIG}"
	{
		_i=11
		while [ "${_i}" -lt 256 ]; do
			printf '${rdomain} '
			_i=$((_i + 1))
		done
		printf '\n'
	} >"${STDIN}"
	{
		_i=11
		while [ "${_i}" -lt 256 ]; do
			printf '%d ' "${_i}"
			_i=$((_i + 1))
		done
		printf '\n'
	} | robsd_config -R -
fi

if testcase "regress timeout hours"; then
	{
		default_regress_config
		echo 'regress-timeout 1h'
	} >"${CONFIG}"
	echo "TIMEOUT=\${regress-timeout}" >"${STDIN}"
	robsd_config -R - <<-EOF
	TIMEOUT=3600
	EOF
fi

if testcase "regress timeout minutes"; then
	{
		default_regress_config
		echo 'regress-timeout 1m'
	} >"${CONFIG}"
	echo "TIMEOUT=\${regress-timeout}" >"${STDIN}"
	robsd_config -R - <<-EOF
	TIMEOUT=60
	EOF
fi

if testcase "regress timeout seconds"; then
	{
		default_regress_config
		echo 'regress-timeout 1s'
	} >"${CONFIG}"
	echo "TIMEOUT=\${regress-timeout}" >"${STDIN}"
	robsd_config -R - <<-EOF
	TIMEOUT=1
	EOF
fi

if testcase "regress timeout invalid unit"; then
	{
		default_regress_config
		echo 'regress-timeout 1a'
	} >"${CONFIG}"
	robsd_config -R -e - <<-EOF
	robsd-config: ${CONFIG}:6: unknown timeout unit
	EOF
fi

if testcase "regress timeout invalid too large"; then
	{
		default_regress_config
		echo 'regress-timeout 2147483647h'
	} >"${CONFIG}"
	robsd_config -R -e - <<-EOF
	robsd-config: ${CONFIG}:6: timeout too large
	EOF
fi

if testcase "regress invalid flags"; then
	echo 'regress "bin/csh" noway' >"${CONFIG}"
	robsd_config -R -e | grep -e noway >"${TMP1}"
	assert_file - "${TMP1}" <<-EOF
	robsd-config: ${CONFIG}:1: unknown keyword 'noway'
	EOF
fi

if testcase "boolean yes"; then
	{ default_regress_config; echo 'rdonly yes'; } >"${CONFIG}"
	echo "RDONLY=\${rdonly}" >"${STDIN}"
	robsd_config -R - <<-EOF
	RDONLY=1
	EOF
fi

if testcase "boolean no"; then
	{ default_regress_config; echo 'rdonly no'; } >"${CONFIG}"
	echo "RDONLY=\${rdonly}" >"${STDIN}"
	robsd_config -R - <<-EOF
	RDONLY=0
	EOF
fi

if testcase "boolean default value"; then
	default_regress_config >"${CONFIG}"
	echo "RDONLY=\${rdonly}" >"${STDIN}"
	robsd_config -R - <<-EOF
	RDONLY=0
	EOF
fi

if testcase "integer default value"; then
	default_config >"${CONFIG}"
	echo "KEEP=\${keep}" >"${STDIN}"
	robsd_config - <<-EOF
	KEEP=0
	EOF
fi

if testcase "string default value"; then
	default_config >"${CONFIG}"
	echo "STRING=\${distrib-host}" >"${STDIN}"
	robsd_config - <<-EOF
	STRING=
	EOF
fi

if testcase "string interpolation"; then
	{
		default_config
		echo "kernel \"\${robsddir}\""
	} >"${CONFIG}"
	echo "\${kernel}" >"${STDIN}"
	robsd_config - <<-EOF
	${TSHDIR}
	EOF
fi

if testcase "list default value"; then
	default_config >"${CONFIG}"
	echo "SKIP=\${skip}" >"${STDIN}"
	robsd_config - <<-EOF
	SKIP=
	EOF
fi

if testcase "list interpolation"; then
	{
		default_config
		echo "skip { \"ROBSDDIR=\${robsddir}\" }"
	} >"${CONFIG}"
	echo "\${skip}" >"${STDIN}"
	robsd_config - <<-EOF
	ROBSDDIR=${TSHDIR}
	EOF
fi

if testcase "glob"; then
	touch "${TSHDIR}/src-one.diff" "${TSHDIR}/src-two.diff"
	{
		default_config
		echo "bsd-diff \"${TSHDIR}/src-*.diff\""
		echo "x11-diff \"${TSHDIR}/x11-*.diff\""
	} >"${CONFIG}"
	echo "'\${bsd-diff}' '\${x11-diff}'" >"${STDIN}"
	robsd_config - <<-EOF
	'${TSHDIR}/src-one.diff ${TSHDIR}/src-two.diff' ''
	EOF
fi

if testcase "hook"; then
	{
		default_config
		echo "hook { \"echo\" \"\${robsddir}\" }"
	} >"${CONFIG}"
	echo "\${hook}" >"${STDIN}"
	robsd_config - <<-EOF
	echo ${TSHDIR}
	EOF
fi

if testcase "comment"; then
	{
		default_config
		echo "# comment"
		echo "keep 0 # comment"
	} >"${CONFIG}"
	echo "KEEP=\${keep}" >"${STDIN}"
	robsd_config - <<-EOF
	KEEP=0
	EOF
fi

if testcase "read only variables"; then
	_arch="$(arch -s 2>/dev/null || arch)"
	_machine="$(machine 2>/dev/null || arch)"

	echo /builddir >"${TSHDIR}/.running"
	default_config >"${CONFIG}"
	cat <<-'EOF' >"${STDIN}"
	${arch}
	${machine}
	${keep-dir}
	${builddir}
	EOF

	robsd_config - <<-EOF
	${_arch}
	${_machine}
	${TSHDIR}/attic
	/builddir
	EOF
fi

if testcase "builddir lock file missing"; then
	: >"${TSHDIR}/.running"
	default_config >"${CONFIG}"
	echo "\${builddir}" >"${STDIN}"
	robsd_config -e - <<-EOF
	robsd-config: ${TSHDIR}/.running: line not found
	robsd-config: /dev/stdin:1: invalid substitution, unknown variable 'builddir'
	EOF
fi

if testcase "builddir lock file empty"; then
	default_config >"${CONFIG}"
	echo "\${builddir}" >"${STDIN}"
	robsd_config -e - <<-EOF
	robsd-config: /dev/stdin:1: invalid substitution, unknown variable 'builddir'
	EOF
fi

if testcase "ncpu"; then
	default_config >"${CONFIG}"
	echo "\${ncpu}" >"${STDIN}"
	_ncpu="$(robsd_config)"
	if [ "${_ncpu}" -eq 0 ]; then
		fail "expected ncpu to be non-zero"
	fi
fi

if testcase "invalid missing file"; then
	robsd_config -e -- -f /nein >/dev/null
fi

if testcase "invalid grammar"; then
	cat <<-EOF >"${CONFIG}"
	FOO=bar
	EOF
	robsd_config -e | head -1 >"${TMP1}"
	assert_file - "${TMP1}" <<-EOF
	robsd-config: ${CONFIG}:1: want KEYWORD, got UNKNOWN
	EOF
fi

if testcase "invalid directory missing"; then
	{
		default_config | sed -e '/bsd-objdir/d'
		echo 'bsd-objdir "/nein"'
	} >"${CONFIG}"
	robsd_config -e - <<-EOF
	robsd-config: ${CONFIG}:6: /nein: No such file or directory
	EOF
fi

if testcase "invalid not a directory"; then
	{
		printf 'bsd-objdir "%s"\n' "${CONFIG}"
		default_config | sed -e '/bsd-objdir/d'
	} >"${CONFIG}"
	robsd_config -e - <<-EOF
	robsd-config: ${CONFIG}:1: ${CONFIG}: is not a directory
	EOF
fi

if testcase "invalid already defined"; then
	{ default_config; echo 'robsddir "/tmp"'; } >"${CONFIG}"
	robsd_config -e - <<-EOF
	robsd-config: ${CONFIG}:7: variable 'robsddir' already defined
	EOF
fi

if testcase "invalid missing mandatory"; then
	robsd_config -e | grep -e mandatory >"${TMP1}"
	assert_file - "${TMP1}" <<-EOF
	robsd-config: ${CONFIG}: mandatory variable 'destdir' missing
	robsd-config: ${CONFIG}: mandatory variable 'robsddir' missing
	EOF
fi

if testcase "invalid empty mandatory"; then
	{
		printf 'robsddir ""\n'
		default_config | sed -e '/robsddir/d'
	} >"${CONFIG}"
	robsd_config -e | grep -v -e mandatory >"${TMP1}"
	assert_file - "${TMP1}" <<-EOF
	robsd-config: ${CONFIG}:1: empty string
	EOF
fi

if testcase "invalid variable value"; then
	cat <<-EOF >"${CONFIG}"
	bsd-objdir 1
	bsd-srcdir 1
	EOF
	robsd_config -e | grep -v -e mandatory >"${TMP1}"
	assert_file - "${TMP1}" <<-EOF
	robsd-config: ${CONFIG}:1: want STRING, got INTEGER
	robsd-config: ${CONFIG}:2: want STRING, got INTEGER
	EOF
fi

if testcase "invalid keyword"; then
	cat <<-EOF >"${CONFIG}"
	one 1
	two 2
	EOF
	robsd_config -e | grep -v -e mandatory >"${TMP1}"
	assert_file - "${TMP1}" <<-EOF
	robsd-config: ${CONFIG}:1: unknown keyword 'one'
	EOF
fi

if testcase "invalid integer overflow"; then
	cat <<-EOF >"${CONFIG}"
	keep 1111111111111111111111111111111111111111
	reboot "nein"
	EOF
	robsd_config -e >"${TMP1}"
	assert_file - "${TMP1}" <<-EOF
	robsd-config: ${CONFIG}:1: integer too big
	robsd-config: ${CONFIG}:2: want BOOLEAN, got STRING
	EOF
fi

if testcase -t memleak "invalid user"; then
	cat <<-EOF >"${CONFIG}"
	cvs-user "unknown"
	EOF
	robsd_config -e | grep -v -e mandatory >"${TMP1}"
	assert_file - "${TMP1}" <<-EOF
	robsd-config: ${CONFIG}:1: user 'unknown' not found
	EOF
fi

if testcase "invalid unterminated string"; then
	printf 'robsddir "' >"${CONFIG}"
	robsd_config -e | grep -v -e mandatory >"${TMP1}"
	assert_file - "${TMP1}" <<-EOF
	robsd-config: ${CONFIG}:1: unterminated string
	EOF
fi

if testcase "invalid template missing {"; then
	default_config >"${CONFIG}"
	cat <<-'EOF' >"${STDIN}"
	FOO=$
	EOF
	robsd_config -e - <<-EOF
	robsd-config: /dev/stdin:1: invalid substitution, expected '{'
	EOF
fi

if testcase "invalid template missing }"; then
	default_config >"${CONFIG}"
	cat <<-'EOF' >"${STDIN}"
	FOO=${
	EOF
	robsd_config -e - <<-EOF
	robsd-config: /dev/stdin:1: invalid substitution, expected '}'
	EOF
fi

if testcase "invalid template empty variable name"; then
	default_config >"${CONFIG}"
	cat <<-'EOF' >"${STDIN}"
	FOO=${}
	EOF
	robsd_config -e - <<-EOF
	robsd-config: /dev/stdin:1: invalid substitution, empty variable name
	EOF
fi

if testcase "invalid template unknown variable name"; then
	default_config >"${CONFIG}"
	cat <<-'EOF' >"${STDIN}"
	FOO=${foo}
	EOF
	robsd_config -e - <<-EOF
	robsd-config: /dev/stdin:1: invalid substitution, unknown variable 'foo'
	EOF
fi

if testcase "invalid mode"; then
	if "${ROBSDCONFIG}" -m unknown >"${TMP1}" 2>&1; then
		fail - "expected exit non-zero" <"${TMP1}"
	fi
fi

if testcase "invalid not found"; then
	if ${EXEC:-} "${ROBSDCONFIG}" -m robsd -C /var/empty/nein >"${TMP1}" 2>&1; then
		fail - "expected exit non-zero" <"${TMP1}"
	fi
	assert_file - "${TMP1}" <<-EOF
	robsd-config: /var/empty/nein: No such file or directory
	EOF
fi

if testcase "invalid arguments"; then
	if ${EXEC:-} "${ROBSDCONFIG}" -nein >"${TMP1}" 2>&1; then
		fail - "expected exit non-zero" <"${TMP1}"
	fi
	if ! grep -q usage "${TMP1}"; then
		fail - "expected usage" <"${TMP1}"
	fi
fi

if testcase "invalid recursive interpolation"; then
	{ default_config; echo 'distrib-host "${distrib-host}"'; } >"${CONFIG}"
	cat <<-'EOF' >"${STDIN}"
	${distrib-host}
	EOF
	robsd_config -e - <<-EOF
	robsd-config: /dev/stdin:1: invalid substitution, recursion too deep
	EOF
fi

if testcase "invalid read only assign"; then
	{ default_config; echo 'arch "exotic"'; } >"${CONFIG}"
	robsd_config -e - <<-EOF
	robsd-config: ${TSHDIR}/robsd.conf:7: unknown keyword 'arch'
	EOF
fi

if testcase "invalid afl"; then
	printf 'robsddir \00"/tmp"\n' >"${CONFIG}"
	robsd_config -e - <<-EOF
	robsd-config: ${CONFIG}:1: want STRING, got EOF
	EOF
fi
