. "${EXECDIR}/util.sh"

_tmpdir="${BUILDDIR}/tmp"

for _d in "$BSDSRCDIR" "$XSRCDIR"; do
	unpriv "$CVSUSER" "cd ${_d} && exec cvs -q -d ${CVSROOT} update -Pd" 2>&1 |
		tee "${_tmpdir}/cvs.log"
	find "$_d" -type f -name Root -delete
	cvs_log -r "$_d" -t "$_tmpdir" -u "$CVSUSER" <"${_tmpdir}/cvs.log"
done
