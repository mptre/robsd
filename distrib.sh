cd "$RELEASEDIR"
rm -f SHA256
sha256 -h SHA256 *

su "$SSHUSER" -c "ssh ${SSHHOST} rm -f ${SSHPATH}/*"
su "$SSHUSER" -c "scp ${RELEASEDIR}/* ${SSHHOST}:${SSHPATH}"
