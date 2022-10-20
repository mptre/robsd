. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-regress.sh"

config_load <<'EOF'
SUDO="${sudo}"
BSDSRCDIR="${bsd-srcdir}"
REGRESSUSER="${regress-user}"
EOF

_pkg_del=""
_pkg_add="$(config_value "regress-${1}-packages" 2>/dev/null || :)"
for _p in $_pkg_add; do
	PKG_PATH='' pkg_info "$_p" >/dev/null && continue

	if pkg_add "$_p"; then
		_pkg_del="${_pkg_del} ${_p}"
	fi
done

_err=0
_log="${BUILDDIR}/tmp/regress"; : >"$_log"; chmod 666 "$_log"
_env="$(config_value "regress-${1}-env" 2>/dev/null || :)"
_make="${_env:+env ${_env}} make -C ${BSDSRCDIR}/regress/${1} REGRESS_LOG=${_log} REGRESS_FAIL_EARLY=no"
if regress_root "$1"; then
	$_make || _err="$?"
else
	export SUDO
	unpriv "$REGRESSUSER" "$_make" || _err="$?"
fi

for _p in $_pkg_del; do
	pkg_delete "$_p" || :
done

# Add extra headers to report.
_fail="$(sed -n -e "s,${1}/,," -e 's/^FAIL //p' "$_log" | xargs)"
[ -z "$_fail" ] || echo "X-Fail: ${_fail}"
_skip="$(sed -n -e "s,${1}/,," -e 's/^SKIP //p' "$_log" | xargs)"
[ -z "$_skip" ] || echo "X-Skip: ${_skip}"

rm -f "$_log"
exit "$_err"
