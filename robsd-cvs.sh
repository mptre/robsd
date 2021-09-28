. "${EXECDIR}/util.sh"

for d in "$BSDSRCDIR" "$XSRCDIR"; do
	_tmpdir="${BUILDDIR}/tmp"

	unpriv "$CVSUSER" "cd ${d} && exec cvs -q -d ${CVSROOT} update -Pd" 2>&1 |
		tee "${_tmpdir}/cvs.log"
	find "$d" -type f -name Root -delete

	cvs_log -r "$d" -t "$_tmpdir" -u "$CVSUSER" <"${_tmpdir}/cvs.log"
done
