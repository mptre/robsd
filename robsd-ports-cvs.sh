. "${EXECDIR}/util.sh"

unpriv "$CVSUSER" "cd ${CHROOT}${PORTSDIR} && exec cvs -q -d ${CVSROOT} update -Pd"
