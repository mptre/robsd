. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-regress.sh"

config_load <<'EOF'
SUDO="${sudo}"
BSDSRCDIR="${bsd-srcdir}"
REGRESSUSER="${regress-user}"
EOF

_err=0
_log="${BUILDDIR}/tmp/regress"; : >"$_log"; chmod 666 "$_log"
_env="REGRESS_LOG=${_log} REGRESS_FAIL_EARLY=no"
_env="env ${_env} $(config_value "regress-${1}-env" 2>/dev/null || :)"
_target="$(config_value "regress-${1}-target")"
_make="${_env} make -C ${BSDSRCDIR}/regress/${1} ${_target}"
if regress_root "$1"; then
	$_make || _err="$?"
else
	export SUDO
	# Since we're most likely running as the build user, use a more generous
	# login class as some regression tests are resource hungry.
	unpriv -c staff "$REGRESSUSER" "exec ${_make}" || _err="$?"
fi

# Add extra headers to report.
_fail="$(sed -n -e "s,${1}/,," -e 's/^FAIL //p' "$_log" | xargs)"
[ -z "$_fail" ] || echo "X-Fail: ${_fail}"
_skip="$(sed -n -e "s,${1}/,," -e 's/^SKIP //p' "$_log" | xargs)"
[ -z "$_skip" ] || echo "X-Skip: ${_skip}"

rm -f "$_log"
exit "$_err"
