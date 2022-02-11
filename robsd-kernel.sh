. "${EXECDIR}/util.sh"

kernel_path() {
	local _n _s

	_n="$(sysctl -n hw.ncpu)"
	_s="$(test "$_n" -gt 1 && echo '.MP')"

	printf 'arch/%s/compile/GENERIC%s\n' "$(machine)" "$_s"
}

config_load <<'EOF'
BSDOBJDIR="${bsd-objdir}"; export BSDOBJDIR
BSDSRCDIR="${bsd-srcdir}"; export BSDSRCDIR
BUILDUSER="${builduser}"
EOF

cd "${BSDSRCDIR}/sys/$(kernel_path)"

# Cannot create object directory symlink as build user.
make obj

unpriv "$BUILDUSER" <<EOF
make config
make && exit 0

# Try again this time with a clean slate.
make clean
make config
make
EOF

make install
