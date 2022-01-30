. "${EXECDIR}/util.sh"

kernel_path() {
	local _n _s

	_n="$(sysctl -n hw.ncpu)"
	_s="$(test "$_n" -gt 1 && echo '.MP')"

	printf 'arch/%s/compile/GENERIC%s\n' "$(machine)" "$_s"
}

config_load <<'EOF'
BSDSRCDIR="${bsd-srcdir}"
BUILDUSER="${builduser}"
EOF

cd "${BSDSRCDIR}/sys/$(kernel_path)"

unpriv "$BUILDUSER" <<EOF
make obj
make config
make && exit 0

# Try again this time with a clean slate.
make clean
make config
make
EOF

make install
