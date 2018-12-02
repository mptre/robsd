su "$SSHUSER" -c "ssh ${SSHHOST} rm -f ${SSHPATH}/*"
su "$SSHUSER" -c "scp ${RELEASEDIR}/* ${SSHHOST}:${SSHPATH}"
