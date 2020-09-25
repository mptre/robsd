. "${EXECDIR}/util.sh"

# Required by $BSDSRCDIR/etc/Makefile.
chown build "$DESTDIR"
chmod 700 "$DESTDIR"

DESTDIR="${DESTDIR}/src"
mkdir -p "$DESTDIR"
cleandir "$DESTDIR"

RELEASEDIR="$(release_dir "$LOGDIR")"; export RELEASEDIR
mkdir -p "$RELEASEDIR"
cleandir "$RELEASEDIR"
chown build "$RELEASEDIR"
chmod 755 "$RELEASEDIR"

# Remove vnd devices in case of resuming.
make -C "${BSDSRCDIR}/distrib/$(machine)" unconfig

cd "${BSDSRCDIR}/etc"
make release
