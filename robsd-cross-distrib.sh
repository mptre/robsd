. "${EXECDIR}/util.sh"

config_load <<'EOF'
CROSSDIR="${crossdir}"
BSDSRCDIR="${bsd-srcdir}"
TARGET="${target}"
EOF

cd "$BSDSRCDIR"
make -f Makefile.cross "TARGET=${TARGET}" "CROSSDIR=${CROSSDIR}" cross-distrib
