. "${EXECDIR}/util.sh"

config_load <<'EOF'
DESTDIR="${destdir}/src"; export DESTDIR
BSDSRCDIR="${bsd-srcdir}"
EOF

cd "${BSDSRCDIR}/distrib/sets"
sh checkflist || :
