. "${EXECDIR}/util.sh"

config_load <<'EOF'
SUDO="${sudo}"
BSDSRCDIR="${bsd-srcdir}"
REGRESSUSER="${regress-user}"
EOF

if regress_root "$1"; then
	exec make -C "${BSDSRCDIR}/regress/${1}"
else
	export SUDO
	unpriv "$REGRESSUSER" "exec make -C ${BSDSRCDIR}/regress/${1}"
fi
