. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-regress.sh"

config_load <<-'EOF'
TMPDIR="${tmp-dir}"
EOF

{ config_value regress-packages 2>/dev/null || :; } |
xargs printf '%s\n' | sort | uniq |
while read -r _p; do
	if ! PKG_PATH='' pkg_info "$_p" >/dev/null 2>&1; then
		echo "$_p" >>"${TMPDIR}/packages"
	fi
done

[ -e "${TMPDIR}/packages" ] || exit 0
xargs pkg_add -Dsnapshot <"${TMPDIR}/packages" || :
