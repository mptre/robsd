. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-ports.sh"
. "${EXECDIR}/util-regress.sh"

config_load <<-'EOF'
BUILDDIR="${builddir}"
EOF

# shellcheck disable=SC2016
dmesg | sed -n 'H;/^OpenBSD/h;${g;p;}' >"${BUILDDIR}/dmesg"
