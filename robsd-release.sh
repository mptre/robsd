. "${EXECDIR}/util.sh"

config_load <<'EOF'
DESTDIR="${destdir}"
BSDSRCDIR="${bsd-srcdir}"
EOF

chown build "$DESTDIR"
chmod 700 "$DESTDIR"

DESTDIR="${DESTDIR}/src"; export DESTDIR
mkdir -p "$DESTDIR"
cleandir "$DESTDIR"

RELEASEDIR="$(release_dir "$BUILDDIR")"; export RELEASEDIR
mkdir -p "$RELEASEDIR"
cleandir "$RELEASEDIR"
chown build "$RELEASEDIR"
chmod 755 "$RELEASEDIR"

# Remove vnd devices in case of resuming.
make -C "${BSDSRCDIR}/distrib/$(machine)" unconfig

cd "${BSDSRCDIR}/etc"
make release
