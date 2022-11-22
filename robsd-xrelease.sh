. "${EXECDIR}/util.sh"

config_load <<'EOF'
BUILDDIR="${builddir}"
DESTDIR="${destdir}"
XSRCDIR="${x11-srcdir}"
EOF

DESTDIR="${DESTDIR}/xenocara"; export DESTDIR
mkdir -p "$DESTDIR"
cleandir "$DESTDIR"

RELEASEDIR="$(release_dir -x "$BUILDDIR")"; export RELEASEDIR
mkdir -p "$RELEASEDIR"
cleandir "$RELEASEDIR"
chown build "$RELEASEDIR"
chmod 755 "$RELEASEDIR"

# Not suitable for parallelism.
unset MAKEFLAGS
cd "$XSRCDIR"
make release
make checkdist
