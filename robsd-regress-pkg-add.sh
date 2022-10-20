. "${EXECDIR}/util.sh"

_tmpdir="${BUILDDIR}/tmp"

_packages="$(config_value regress-packages 2>/dev/null || :)"
for _p in $_packages; do
	PKG_PATH='' pkg_info "$_p" >/dev/null && continue

	pkg_add "$_p" || :
	echo "$_p" >>"${_tmpdir}/packages"
done
