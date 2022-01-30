. "${EXECDIR}/util.sh"

config_load <<'EOF'
RDONLY="${rdonly}"
BSDSRCDIR="${bsd-srcdir}"
EOF

[ "$RDONLY" -eq 1 ] || exit 0

mount -uw "$BSDSRCDIR"
