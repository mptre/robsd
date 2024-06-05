. "${EXECDIR}/util.sh"

config_load <<'EOF'
DESTDIR="${destdir}"
BSDSRCDIR="${bsd-srcdir}"
RELEASEDIR="${bsd-reldir}"; export RELEASEDIR
EOF

chown build "${DESTDIR}"
chmod 700 "${DESTDIR}"

DESTDIR="${DESTDIR}/src"; export DESTDIR
mkdir -p "${DESTDIR}"
cleandir "${DESTDIR}"

mkdir -p "${RELEASEDIR}"
cleandir "${RELEASEDIR}"
chown build "${RELEASEDIR}"
chmod 755 "${RELEASEDIR}"

# Remove vnd devices in case of resuming. As some architectures does not support
# this make target, ignore errors.
make -C "${BSDSRCDIR}/distrib/$(machine)" unconfig || :

cd "${BSDSRCDIR}/etc"
make release
