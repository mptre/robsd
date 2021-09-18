set -u

# config_stub [-] [mode]
config_stub() {
	local _stdin=0
	local _mode="robsd"

	while [ "$#" -gt 0 ]; do
		case "$1" in
		-)	_stdin=1;;
		*)	break;;
		esac
		shift
	done
	[ "$#" -gt 0 ] && _mode="$1"

	ROBSDCONF="${TSHDIR}/${_mode}.conf"; export ROBSDCONF
	{
		cat <<-EOF
		BSDSRCDIR=${TSHDIR}
		ROBSDDIR=${TSHDIR}
		CVSROOT=example.com:/cvs
		CVSUSER=nobody
		DESTDIR=/var/empty
		XSRCDIR=${TSHDIR}
		EOF
		[ "$_stdin" -eq 1 ] && cat
	} >"$ROBSDCONF"
}

# utility_setup
utility_setup() {
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

	cat <<-EOF >"${_bindir}/su"
	shift 2 # strip of su login
	\$@
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
DETACH=0; export DETACH
HOOK=""; export HOOK
PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin"; export PATH
TMP1="${TSHDIR}/tmp1"; export TMP1
SKIPIGNORE=""; export SKIPIGNORE

. "${EXECDIR}/util.sh"

setprogname "robsd-test"
