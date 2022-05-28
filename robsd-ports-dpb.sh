. "${EXECDIR}/util.sh"

# duration pattern
duration() {
	local _pattern

	_pattern="$1"; : "${_pattern:?}"
	grep -m 1 "$_pattern" | awk '{print $NF}' | sed 's/\..*//'
}

config_load <<'EOF'
CHROOT="${chroot}"
PORTSDIR="${ports-dir}"
PORTS="${ports}"
EOF

PATH="${CHROOT}${PORTSDIR}/infrastructure/bin:${PATH}"

_arch="$(machine)"

xargs -t rm -rf <<EOF
${CHROOT}${PORTSDIR}/logs/${_arch}
${CHROOT}${PORTSDIR}/distfiles/build-stats/${_arch}
EOF

_tmpdir="${BUILDDIR}/tmp"
ls "${CHROOT}${PORTSDIR}/packages/${_arch}/all" >"${_tmpdir}/packages.orig" 2>/dev/null || :

# shellcheck disable=SC2086
dpb -c -B "$CHROOT" $PORTS

# Look for errors.
! grep -m 1 'E='"${CHROOT}${PORTSDIR}/logs/${_arch}/stats.log"

ls "${CHROOT}${PORTSDIR}/packages/${_arch}/all" >"${_tmpdir}/packages"
diff -U0 -L packages.orig -L packages "${_tmpdir}/packages.orig" "${_tmpdir}/packages" || :
