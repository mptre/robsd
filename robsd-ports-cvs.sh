. "${EXECDIR}/util.sh"

_d="${CHROOT}${PORTSDIR}"
_tmpdir="${BUILDDIR}/tmp"

unpriv "$CVSUSER" "cd ${_d} && exec cvs -q -d ${CVSROOT} update -Pd" 2>&1 |
	tee "${_tmpdir}/cvs.log"
find "$_d" -type f -name Root -delete
cvs_log -r "${CHROOT}${PORTSDIR}" -t "$_tmpdir" -u "$CVSUSER" <"${_tmpdir}/cvs.log"
