. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-ports.sh"

config_load <<'EOF'
CHROOT="${chroot}"
DPB="${dpb}"
PORTSDIR="${ports-dir}"
TMPDIR="${tmp-dir}"
EOF

PATH="${CHROOT}${PORTSDIR}/infrastructure/bin:${PATH}"

_arch="$(arch -s)"

rm -rf "${CHROOT}${PORTSDIR}/logs/${_arch}"

# Could already be present if the clean step was not skipped.
_packages="${CHROOT}${PORTSDIR}/packages/${_arch}/all"
if ! [ -e "${TMPDIR}/packages.orig" ]; then
	ls "${_packages}" >"${TMPDIR}/packages.orig" 2>/dev/null || :
fi

# shellcheck disable=SC2086
dpb -c -B "${CHROOT}" -P "${TMPDIR}/ports" ${DPB}

# Look for errors.
grep -m 1 'E:' "${CHROOT}${PORTSDIR}/logs/${_arch}/engine.log" && exit 1
grep -m 1 'E=' "${CHROOT}${PORTSDIR}/logs/${_arch}/stats.log" && exit 1

# Produce packages diff used in report.
ls "${_packages}" >"${TMPDIR}/packages"
(cd "${TMPDIR}" && diff -U0 packages{.orig,} >packages.diff) || :
