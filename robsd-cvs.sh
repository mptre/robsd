. "${EXECDIR}/util.sh"

_tmpdir="${BUILDDIR}/tmp"

{
[ "$_MODE" = "robsd" ] && echo src "$BSDSRCDIR"
[ "$_MODE" = "robsd" ] && echo xenocara "$XSRCDIR"
[ "$_MODE" = "robsd-ports" ] && echo ports "${CHROOT}${PORTSDIR}"
} | while read -r _n _d; do
	_ci="${_tmpdir}/cvs-${_n}-ci.log"
	_up="${_tmpdir}/cvs-${_n}-up.log"

	unpriv "$CVSUSER" "cd ${_d} && exec cvs -q -d ${CVSROOT} update -Pd" 2>&1 |
	tee "$_up" |
	cvs_log -r "$_d" -t "$_tmpdir" -u "$CVSUSER" |
	tee "$_ci"

	find "$_d" -type f -name Root -delete
done
