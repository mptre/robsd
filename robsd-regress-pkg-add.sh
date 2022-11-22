. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-regress.sh"

config_load <<-'EOF'
BUILDDIR="${builddir}"
EOF

_tmpdir="${BUILDDIR}/tmp"

_packages="$(config_value regress-packages 2>/dev/null || :)"
for _p in $_packages; do
	if ! PKG_PATH='' pkg_info "$_p" >/dev/null; then
		echo "$_p" >>"${_tmpdir}/packages"
	fi
done

[ -e "${_tmpdir}/packages" ] || exit 0
xargs pkg_add <"${_tmpdir}/packages" || :
