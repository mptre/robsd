. "${EXECDIR}/util.sh"

config_load <<'EOF'
BUILDDIR="${builddir}"
DESTDIR="${destdir}"
BSDSRCDIR="${bsd-srcdir}"
EOF

RELDIR="$(release_dir "$BUILDDIR")"; export RELDIR
RELXDIR="$(release_dir -x "$BUILDDIR")"; export RELXDIR

cd "${BSDSRCDIR}/distrib/$(machine)/iso"
make
make install
