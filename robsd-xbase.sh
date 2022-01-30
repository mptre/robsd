. "${EXECDIR}/util.sh"

config_load <<'EOF'
XOBJDIR="${x11-objdir}"; export XOBJDIR
XSRCDIR="${x11-srcdir}"; export XSRCDIR
EOF

cleandir "$XOBJDIR"
chown build:wobj "$XOBJDIR"
chmod 770 "$XOBJDIR"

cd "$XSRCDIR"
make bootstrap
make obj
make build
