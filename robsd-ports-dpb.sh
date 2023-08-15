. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-ports.sh"

config_load <<'EOF'
BUILDDIR="${builddir}"
CHROOT="${chroot}"
PORTSDIR="${ports-dir}"
EOF

PATH="${CHROOT}${PORTSDIR}/infrastructure/bin:${PATH}"

_arch="$(arch -s)"
_tmpdir="${BUILDDIR}/tmp"

xargs -t rm -rf <<EOF
${CHROOT}${PORTSDIR}/logs/${_arch}
${CHROOT}${PORTSDIR}/distfiles/build-stats/${_arch}
EOF

# Could already be present if the clean step was not skipped.
_packages="${CHROOT}${PORTSDIR}/packages/${_arch}/all"
if ! [ -e "${_tmpdir}/packages.orig" ]; then
	ls "$_packages" >"${_tmpdir}/packages.orig" 2>/dev/null || :
fi

dpb -c -B "$CHROOT" -P "${_tmpdir}/ports"

# Look for errors.
grep -m 1 'E:' "${CHROOT}${PORTSDIR}/logs/${_arch}/engine.log" && exit 1
grep -m 1 'E=' "${CHROOT}${PORTSDIR}/logs/${_arch}/stats.log" && exit 1

# Produce packages diff used in report.
ls "${_packages}" >"${_tmpdir}/packages"
(cd "$_tmpdir" && diff -U0 packages{.orig,} >packages.diff) || :
