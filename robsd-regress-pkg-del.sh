. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-regress.sh"

config_load <<-'EOF'
BUILDDIR="${builddir}"
EOF

_tmpdir="${BUILDDIR}/tmp"

[ -e "${_tmpdir}/packages" ] || exit 0
xargs pkg_delete <"${_tmpdir}/packages" || :
pkg_delete -a || :
