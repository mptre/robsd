. "${EXECDIR}/util.sh"

# At this point, all release artifacts are present in the rel directory as the
# hash step merges the relx directory into rel.
RELEASEDIR="$(release_dir "$LOGDIR")"
cd "$RELEASEDIR"

if [ -n "$SIGNIFY" ]; then
	signify -Se -s "$SIGNIFY" -m SHA256
fi

ls -nT -- * >index.txt

su "$DISTRIBUSER" -c "exec ssh ${DISTRIBHOST} rm -f ${DISTRIBPATH}/*"
su "$DISTRIBUSER" -c "exec scp ${RELEASEDIR}/* ${DISTRIBHOST}:${DISTRIBPATH}"
