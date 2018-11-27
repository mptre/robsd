kernel_path() {
	local _a _n _s

	_a="$(machine)"
	_n="$(sysctl -n hw.ncpu)"
	_s="$(test $_n -gt 1 && echo '.MP')"

	printf 'arch/%s/compile/GENERIC%s\n' "$_a" "$_s"
}

KERNEL="$(kernel_path)"

cd "${BSDSRCDIR}/sys"
make -C "$KERNEL" obj
make -C "$KERNEL" config
make -C "$KERNEL"
make -C "$KERNEL" install
