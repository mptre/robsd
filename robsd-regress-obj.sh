. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-regress.sh"

config_load <<'EOF'
BSDSRCDIR="${bsd-srcdir}"
EOF

for _d in $(config_value regress); do
	make -C "${BSDSRCDIR}/regress/${_d}" obj
done
for _d in $(config_value regress-obj 2>/dev/null || :); do
	make -C "${BSDSRCDIR}/${_d}" obj
done
