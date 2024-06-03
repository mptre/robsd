. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-ports.sh"

config_load <<'EOF'
CHROOT="${chroot}"
PORTSDIR="${ports-dir}"
TMPDIR="${tmp-dir}"
EOF

_arch="$(arch -s)"

# Take note of all packages before deletion.
_packages="${CHROOT}${PORTSDIR}/packages/${_arch}/all"
ls "$_packages" >"${TMPDIR}/packages.orig" 2>/dev/null || :

cd "${CHROOT}${PORTSDIR}"
rm -rf {bulk,distfiles,locks,logs,packages,plist,pobj,update}
