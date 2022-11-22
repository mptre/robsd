. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-ports.sh"

config_load <<'EOF'
BUILDDIR="${builddir}"
CHROOT="${chroot}"
PORTSDIR="${ports-dir}"
EOF

_arch="$(arch -s)"
_tmpdir="${BUILDDIR}/tmp"

# Take note of all packages before deletion.
_packages="${CHROOT}${PORTSDIR}/packages/${_arch}/all"
ls "$_packages" >"${_tmpdir}/packages.orig" 2>/dev/null || :

cd "${CHROOT}${PORTSDIR}"
rm -rf {bulk,distfiles,locks,logs,packages,plist,pobj,update}
