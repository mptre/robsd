. "${EXECDIR}/util.sh"

_tmpdir="${BUILDDIR}/tmp"

{
echo src "$BSDSRCDIR"
echo xenocara "$XSRCDIR"
} | while read -r _n _d; do
	_ci="${_tmpdir}/cvs-${_n}-ci.log"
	_up="${_tmpdir}/cvs-${_n}-up.log"
	unpriv "$CVSUSER" "cd ${_d} && exec cvs -q -d ${CVSROOT} update -Pd" 2>&1 |
		tee "$_up"
	find "$_d" -type f -name Root -delete
	cvs_log -r "$_d" -t "$_tmpdir" -u "$CVSUSER" <"$_up" | tee "$_ci"
done
