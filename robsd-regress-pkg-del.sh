. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-regress.sh"

config_load <<-'EOF'
TMPDIR="${tmp-dir}"
EOF

[ -e "${TMPDIR}/packages" ] || exit 0
xargs pkg_delete <"${TMPDIR}/packages" || :
pkg_delete -a || :
