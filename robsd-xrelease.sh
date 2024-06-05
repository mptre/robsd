. "${EXECDIR}/util.sh"

config_load <<'EOF'
BUILDDIR="${builddir}"
DESTDIR="${destdir}"
RELEASEDIR="${x11-reldir}"; export RELEASEDIR
XSRCDIR="${x11-srcdir}"
EOF

PATH="${PATH}:/usr/X11R6/bin"; export PATH

DESTDIR="${DESTDIR}/xenocara"; export DESTDIR
mkdir -p "${DESTDIR}"
cleandir "${DESTDIR}"

mkdir -p "${RELEASEDIR}"
cleandir "${RELEASEDIR}"
chown build "${RELEASEDIR}"
chmod 755 "${RELEASEDIR}"

# Not suitable for parallelism.
unset MAKEFLAGS
cd "${XSRCDIR}"
make release
make checkdist
