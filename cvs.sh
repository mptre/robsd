cd "$BSDSRCDIR"
su "$CVSUSER" -c "cvs -q -d ${CVSROOT} update -Pd"
