set -u

# robsd_config [-CPR] [-]
robsd_config() {
	local _stdin=0
	local _mode="robsd"

	while [ "$#" -gt 0 ]; do
		case "$1" in
		-C)	_mode="robsd-cross";;
		-P)	_mode="robsd-ports";;
		-R)	_mode="robsd-regress";;
		-)	_stdin=1;;
		*)	break;;
		esac
		shift
	done

	ROBSDCONF="${TSHDIR}/robsd.conf"; export ROBSDCONF
	{
		case "$_mode" in
		robsd)
			cat <<-EOF
			destdir "/var/empty"
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
			regress-user "nobody"
			EOF
			;;
		*)
			return 1
			;;
		esac

		[ "$_stdin" -eq 1 ] && cat
	} >"$ROBSDCONF"

	if ! grep -q execdir "$ROBSDCONF"; then
		echo "execdir \"${TSHDIR}\"" >>"$ROBSDCONF"
	fi
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
	mkdir "$_bindir"

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
	shift 2 # strip of su login
	if [ $# -gt 0 ]; then
		$@
	else
		sh
	fi
	EOF
	chmod u+x "${_bindir}/su"

	ROBSDDIR="${TSHDIR}/build"
	mkdir "$ROBSDDIR"

	echo "$_tmpdir" "$_bindir" "$ROBSDDIR"
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

ROBSDDIR="$TSHDIR"; export ROBSDDIR
PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin"; export PATH
TMP1="${TSHDIR}/tmp1"; export TMP1

. "${EXECDIR}/util.sh"

setmode "robsd"
setprogname "robsd-test"
