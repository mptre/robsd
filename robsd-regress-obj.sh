. "${EXECDIR}/util.sh"

config_load <<'EOF'
BSDSRCDIR="${bsd-srcdir}"
REGRESS="${regress}"
EOF

for _d in ${REGRESS}; do
	make -C "${BSDSRCDIR}/regress/${_d}" obj
done
