. "${EXECDIR}/util.sh"

_target="$(<"${BUILDDIR}/target")"
config_load -v "target=${_target}" <<'EOF'
CROSSDIR="${crossdir}"
BSDSRCDIR="${bsd-srcdir}"
TARGET="${target}"
EOF

cd "$BSDSRCDIR"
make -f Makefile.cross "TARGET=${TARGET}" "CROSSDIR=${CROSSDIR}" cross-tools
