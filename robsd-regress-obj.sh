. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-regress.sh"

config_load <<'EOF'
BSDSRCDIR="${bsd-srcdir}"
EOF

for _r in $(config_value regress); do
	_d="${BSDSRCDIR}/regress/${_r}"
	_f="$(regress_makefile "$_d")"
	make -C "$_d" ${_f:+-f "$_f"} obj || :
done
for _r in $(config_value regress-obj 2>/dev/null || :); do
	_d="${BSDSRCDIR}/${_r}"
	_f="$(regress_makefile "$_d")"
	make -C "$_d" ${_f:+-f "$_f"} obj
done
