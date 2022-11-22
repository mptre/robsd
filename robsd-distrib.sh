. "${EXECDIR}/util.sh"

config_load <<'EOF'
BUILDDIR="${builddir}"
DISTRIBHOST="${distrib-host}"
DISTRIBPATH="${distrib-path}"
DISTRIBUSER="${distrib-user}"
SIGNIFY="${distrib-signify}"
EOF

# At this point, all release artifacts are present in the rel directory as the
# hash step merges the relx directory into rel.
_releasedir="$(release_dir "$BUILDDIR")"
cd "$_releasedir"

if [ -n "$SIGNIFY" ]; then
	signify -Se -s "$SIGNIFY" -m SHA256
fi

ls -nT -- * >index.txt

if [ -z "$DISTRIBHOST" ] || [ -z "$DISTRIBPATH" ] || [ -z "$DISTRIBUSER" ]; then
	exit 0
fi

unpriv "$DISTRIBUSER" <<EOF
ssh -n ${DISTRIBHOST} rm -f ${DISTRIBPATH}/*
cd ${_releasedir} && exec scp -p * ${DISTRIBHOST}:${DISTRIBPATH}
EOF
