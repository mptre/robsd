. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-regress.sh"

config_load <<-'EOF'
TMPDIR="${tmp-dir}"
ENV="${regress-env}"
EOF

echo "==== packages ===="

{ config_value regress-packages 2>/dev/null || :; } |
xargs printf '%s\n' | sort | uniq |
while read -r _p; do
	if ! PKG_PATH='' pkg_info "${_p}" >/dev/null 2>&1; then
		echo "${_p}" >>"${TMPDIR}/packages"
	fi
done
[ -e "${TMPDIR}/packages" ] || exit 0

# Do not treat failures as fatal as regress suite must be resilient against
# absent packages. However, report this step as skipped to get some visibility.
_err=0
${ENV:+env ${ENV}} xargs pkg_add -Dsnapshot <"${TMPDIR}/packages" || _err=$?
if [ "${_err}" -eq 0 ]; then
	echo SUCCESS
else
	echo SKIPPED
fi
