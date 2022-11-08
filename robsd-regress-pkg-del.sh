_tmpdir="${BUILDDIR}/tmp"

[ -e "${_tmpdir}/packages" ] || exit 0
xargs pkg_delete <"${_tmpdir}/packages" || :
pkg_delete -a || :
