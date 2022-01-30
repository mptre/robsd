. "${EXECDIR}/util.sh"

config_load <<-'EOF'
BSDOBJDIR="${bsd-objdir}"; export BSDOBJDIR
BSDSRCDIR="${bsd-srcdir}"; export BSDSRCDIR
EOF

chown build:wobj "$BSDOBJDIR"
chmod 770 "$BSDOBJDIR"

cd "$BSDSRCDIR"
make obj
make build

sysmerge
cd /dev && ./MAKEDEV all
