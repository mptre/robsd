. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-regress.sh"

config_load <<-'EOF'
BUILDDIR="${builddir}"
EOF

_tmpdir="${BUILDDIR}/tmp"

{ config_value regress-packages 2>/dev/null || :; } |
xargs printf '%s\n' | sort | uniq |
while read -r _p; do
	if ! PKG_PATH='' pkg_info "$_p" >/dev/null 2>&1; then
		echo "$_p" >>"${_tmpdir}/packages"
	fi
done

[ -e "${_tmpdir}/packages" ] || exit 0
xargs pkg_add <"${_tmpdir}/packages" || :
