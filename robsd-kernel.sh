. "${EXECDIR}/util.sh"

config_load <<'EOF'
BUILDUSER="${build-user}"
KERNEL="${kernel}"
BSDOBJDIR="${bsd-objdir}"; export BSDOBJDIR
BSDSRCDIR="${bsd-srcdir}"; export BSDSRCDIR
EOF

cd "${BSDSRCDIR}/sys/arch/$(machine)/compile/${KERNEL}"

# Cannot create object directory symlink as build user.
make obj

unpriv "${BUILDUSER}" <<EOF
make config
make && exit 0

# Try again this time with a clean slate.
make clean
make config
make
EOF

make install
