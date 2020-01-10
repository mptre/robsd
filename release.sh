. "${EXECDIR}/util.sh"

cleandir "$DESTDIR"
chown build "$DESTDIR"
chmod 700 "$DESTDIR"

DESTDIR="${DESTDIR}/src"
mkdir -p "$DESTDIR"

mkdir -p "$RELEASEDIR"
chown build "$RELEASEDIR"
chmod 755 "$RELEASEDIR"

# In case of resuming, wipe the release directory and remove vnd devices.
cleandir "$RELEASEDIR"
make -C "${BSDSRCDIR}/distrib/$(machine)" unconfig

cd "${BSDSRCDIR}/etc"
make release
