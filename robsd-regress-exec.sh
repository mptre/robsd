. "${EXECDIR}/util.sh"

config_load <<'EOF'
BSDSRCDIR="${bsd-srcdir}"
REGRESSUSER="${regress-user}"
EOF

if regress_root "$1"; then
	unset SUDO
	exec make -C "${BSDSRCDIR}/regress/${1}"
else
	unpriv "$REGRESSUSER" "exec make -C ${BSDSRCDIR}/regress/${1}"
fi
