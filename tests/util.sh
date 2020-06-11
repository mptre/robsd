set -u

BUILDDIR="$TSHDIR"; export BUILDDIR
HOOK=""; export HOOK
PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin"; export PATH
TMP1="${TSHDIR}/tmp1"; export TMP1

. "${EXECDIR}/util.sh"

setprogname "robsd-test"
