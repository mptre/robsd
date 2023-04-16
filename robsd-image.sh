. "${EXECDIR}/util.sh"

config_load <<'EOF'
BSDSRCDIR="${bsd-srcdir}"
RELDIR="${bsd-reldir}"; export RELDIR
RELXDIR="${x11-reldir}"; export RELXDIR
EOF

cd "${BSDSRCDIR}/distrib/$(machine)/iso"
make
make install
