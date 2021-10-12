. "${EXECDIR}/util.sh"

# At this point, all release artifacts are present in the rel directory as the
# hash step merges the relx directory into rel.
RELEASEDIR="$(release_dir "$BUILDDIR")"
cd "$RELEASEDIR"

if [ -n "$SIGNIFY" ]; then
	signify -Se -s "$SIGNIFY" -m SHA256
fi

ls -nT -- * >index.txt

if [ -z "$DISTRIBHOST" ] || [ -z "$DISTRIBPATH" ] || [ -z "$DISTRIBUSER" ]; then
	exit 0
fi

unpriv "$DISTRIBUSER" <<EOF
ssh -n ${DISTRIBHOST} rm -f ${DISTRIBPATH}/*
cd ${RELEASEDIR} && exec scp -p * ${DISTRIBHOST}:${DISTRIBPATH}
EOF
