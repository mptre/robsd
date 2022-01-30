. "${EXECDIR}/util.sh"

config_load <<'EOF'
DESTDIR="${destdir}"
BSDSRCDIR="${bsd-srcdir}"
EOF

DESTDIR="${DESTDIR}/src"; export DESTDIR

cd "${BSDSRCDIR}/distrib/sets"
sh checkflist || :
