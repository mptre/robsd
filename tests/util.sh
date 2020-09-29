set -u

# config_stub [-]
config_stub() {
	ROBSDRC="${TSHDIR}/robsdrc"; export ROBSDRC
	{
		cat <<-EOF
		BSDSRCDIR=${TSHDIR}
		CVSROOT=example.com:/cvs
		CVSUSER=nobody
		DESTDIR=/var/empty
		EOF
		[ "$#" -eq 1 ] && [ "$1" = "-" ] && cat
	} >"$ROBSDRC"
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

. "${EXECDIR}/util.sh"

setprogname "robsd-test"
