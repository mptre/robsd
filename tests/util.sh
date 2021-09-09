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
	local _tmpdir

	_tmpdir="$(mktemp -d -t robsd.XXXXXX)"
	TSHCLEAN="${TSHCLEAN} ${_tmpdir}"

	mkdir "${_tmpdir}/bin"
	PATH="${_tmpdir}/bin:${PATH}"

	cat <<-EOF >"${_tmpdir}/bin/id"
	echo 0
	EOF
	chmod u+x "${_tmpdir}/bin/id"

	cat <<-EOF >"${_tmpdir}/bin/sendmail"
	exit 0
	EOF
	chmod u+x "${_tmpdir}/bin/sendmail"

	cat <<-EOF >"${_tmpdir}/bin/sysctl"
	if [ "\$2" = "hw.perfpolicy" ]; then
		echo auto
	else
		/usr/sbin/sysctl "$@"
	fi
	EOF
	chmod u+x "${_tmpdir}/bin/sysctl"

	cat <<-EOF >"${_tmpdir}/bin/su"
	shift 2 # strip of su login
	\$@
	EOF
	chmod u+x "${_tmpdir}/bin/su"

	BUILDDIR="${TSHDIR}/build"
	mkdir "$BUILDDIR"

	echo "$_tmpdir" "$BUILDDIR"
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

BUILDDIR="$TSHDIR"; export BUILDDIR
DETACH=0; export DETACH
HOOK=""; export HOOK
PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin"; export PATH
TMP1="${TSHDIR}/tmp1"; export TMP1
SKIPIGNORE=""; export SKIPIGNORE

. "${EXECDIR}/util.sh"

setprogname "robsd-test"
