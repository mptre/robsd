# shellcheck disable=SC2317

set -u

# robsd_config [-CPRc] [-]
robsd_config() {
	local _stdin=0
	local _mode="robsd"

	while [ "$#" -gt 0 ]; do
		case "$1" in
		-C)	_mode="robsd-cross";;
		-P)	_mode="robsd-ports";;
		-R)	_mode="robsd-regress";;
		-c)	_mode="canvas";;
		-)	_stdin=1;;
		*)	break;;
		esac
		shift
	done

	ROBSDCONF="${TSHDIR}/robsd.conf"; export ROBSDCONF
	{
		case "${_mode}" in
		robsd)
			cat <<-EOF
			destdir "${TSHDIR}"
			bsd-srcdir "${TSHDIR}"
			cvs-root "example.com:/cvs"
			cvs-user "nobody"
			x11-srcdir "${TSHDIR}"
			EOF
			;;
		robsd-cross)
			cat <<-EOF
			crossdir "${TSHDIR}"
			bsd-srcdir "${TSHDIR}"
			EOF
			;;
		robsd-ports)
			cat <<-EOF
			chroot "${TSHDIR}"
			cvs-root "example.com:/cvs"
			cvs-user "nobody"
			ports-dir "/ports"
			ports-user "nobody"
			EOF
			;;
		robsd-regress)
			cat <<-EOF
			bsd-srcdir "${TSHDIR}"
			cvs-user "nobody"
			EOF
			;;
		canvas)
			cat <<-EOF
			canvas-name "test"
			EOF
			;;
		*)
			return 1
			;;
		esac

		[ "${_stdin}" -eq 1 ] && cat
	} >"${ROBSDCONF}"
}

# robsd_log_sanitize path
#
# Remove unstable output from robsd.log.
robsd_log_sanitize() {
	local _path

	_path="$1"; : "${_path:?}"
	sed -i \
		-e '/running as pid/d' \
		-e '/^\+ /d' \
		-e 's|parallel \([^ ]*\) .*|parallel \1 I/N|' \
		"${_path}"
}

# robsd_mock
#
# Setup directories and mock out a few utilities need by robsd. Outputs the
# following directories on a single line:
#
# 1. temporary directory that persists between test cases
# 2. bin directory intended to be prepended to PATH
# 3. robsd directory
robsd_mock() {
	local _bindir
	local _tmpdir

	_tmpdir="$(mktemp -d -t robsd.XXXXXX)"
	TSHCLEAN="${TSHCLEAN} ${_tmpdir}"

	_bindir="${_tmpdir}/bin"
	mkdir "${_bindir}"

	cat <<-EOF >"${_tmpdir}/bin/id"
	echo 0
	EOF
	chmod u+x "${_bindir}/id"

	cat <<-EOF >"${_bindir}/sendmail"
	exit 0
	EOF
	chmod u+x "${_bindir}/sendmail"

	cat <<-EOF >"${_bindir}/sysctl"
	if [ "\$2" = "hw.perfpolicy" ]; then
		echo auto
	elif [ "\$2" = "hw.ncpuonline" ]; then
		echo 2
	else
		/usr/sbin/sysctl "\$@"
	fi
	EOF
	chmod u+x "${_bindir}/sysctl"

	cat <<-'EOF' >"${_bindir}/su"
	[ "$1" = "-c" ] && shift 2 # strip if login class
	shift 2 # strip login and shell arguments
	if [ $# -gt 0 ]; then
		$@
	else
		sh
	fi
	EOF
	chmod u+x "${_bindir}/su"

	ROBSDDIR="${TSHDIR}/build"
	mkdir "${ROBSDDIR}"

	echo "${_tmpdir}" "${_bindir}" "${ROBSDDIR}"
}

# robsd_step_exec -m mode step
#
# Execute a single step.
robsd_step_exec() {
	local _err0=0
	local _err1=0
	local _mode=""
	local _out="${TSHDIR}/step"
	local _step

	while [ "$#" -gt 0 ]; do
		case "$1" in
		-m)	shift; _mode="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_mode:?}"
	_step="$1"; : "${_step:?}"

	(setmode "${_mode}" && sh -eux "${_step}") >"${_out}" 2>&1 || _err1="$?"
	if [ "${_err0}" -ne "${_err1}" ]; then
		fail - "expected exit ${_err0}, got ${_err1}" <"${_out}"
	fi
}

# step_header
#
# Get the step file CSV header.
step_header() {
	"${ROBSDSTEP}" -W -f /dev/null -H
}

# step_serialize [-H] [-d duration] [-e exit] [-i skip] [-l log] [-n name] [-s step]
#                [-t time] [-u user] [-a delta]
#
# Serialize the given step into a robsd-step complaint representation.
step_serialize() {
	local _delta="0"
	local _duration="1"
	local _exit="0"
	local _header=1
	local _log=""
	local _name="name"
	local _skip="0"
	local _step="1"
	local _time="1666666666"
	local _user="root"

	while [ "$#" -gt 0 ]; do
		case "$1" in
		-H)	_header=0;;
		-a)	shift; _delta="$1";;
		-d)	shift; _duration="$1";;
		-e)	shift; _exit="$1";;
		-i)	shift; _skip="$1";;
		-l)	shift; _log="$1";;
		-n)	shift; _name="$1";;
		-s)	shift; _step="$1";;
		-t)	shift; _time="$1";;
		-u)	shift; _user="$1";;
		*)	break;;
		esac
		shift
	done

	[ "${_header}" -eq 0 ] || step_header
	printf '%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
		"${_step}" "${_name}" "${_exit}" "${_duration}" "${_delta}" "${_log}" \
		"${_user}" "${_time}" "${_skip}"
}

# diff_create
diff_create() {
	cat <<EOF
diff --git a/foo b/foo
index eca3934..c629ecf 100644
--- a/foo
+++ b/foo
@@ -1,4 +1,4 @@
 int main(void) {
-int x = 0;
+int x = 1;
 return x;
 }
EOF
}

# portable no | yes
#
# Annotate tests as portable or not. Non-portable tests are only executed when
# the PORTABLE environment variable is unset.
portable() {
	if [ -n "${PORTABLE:-}" ] && [ "$1" = "no" ]; then
		exit 0
	fi
}

ROBSDDIR="${TSHDIR}"; export ROBSDDIR
PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin"; export PATH
TMP1="${TSHDIR}/tmp1"; export TMP1
TZ=""; export TZ

# Use a distinct sanitizer exit code.
ASAN_OPTIONS="exitcode=66"; export ASAN_OPTIONS
UBSAN_OPTIONS="exitcode=66"; export UBSAN_OPTIONS

# Enable hardening malloc(3) options on OpenBSD.
case "$(uname -s)" in
OpenBSD)	export MALLOC_OPTIONS="RS";;
*)		;;
esac

[ -z "${VALGRINDRC:-}" ] || export "VALGRIND_OPTS=$(xargs <"${VALGRINDRC}")"

. "${EXECDIR}/util.sh"

setmode "robsd"
setprogname "robsd-test"
