. "${EXECDIR}/util.sh"

config_load <<'EOF'
DISTRIBHOST="${distrib-host}"
DISTRIBPATH="${distrib-path}"
DISTRIBUSER="${distrib-user}"
RELDIR="${bsd-reldir}"
SIGNIFY="${distrib-signify}"
EOF

# At this point, all release artifacts are present in the rel directory as the
# hash step merges the relx directory into rel.
cd "$RELDIR"

if [ -n "$SIGNIFY" ]; then
	signify -Se -s "$SIGNIFY" -m SHA256
fi

ls -nT -- * >index.txt

if [ -z "$DISTRIBHOST" ] || [ -z "$DISTRIBPATH" ] || [ -z "$DISTRIBUSER" ]; then
	exit 0
fi

unpriv "$DISTRIBUSER" <<EOF
ssh -n ${DISTRIBHOST} rm -f ${DISTRIBPATH}/*
cd ${RELDIR} && exec scp -p * ${DISTRIBHOST}:${DISTRIBPATH}
EOF
