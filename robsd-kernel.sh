. "${EXECDIR}/util.sh"

config_load <<'EOF'
BUILDUSER="${builduser}"
KERNEL="${kernel}"
BSDOBJDIR="${bsd-objdir}"; export BSDOBJDIR
BSDSRCDIR="${bsd-srcdir}"; export BSDSRCDIR
EOF

case "$_MODE" in
robsd-cross)
	_target="$(<"${BUILDDIR}/target")"
	config_load -v "target=${_target}" <<-'EOF'
	CROSSDIR="${crossdir}"
	TARGET="${target}"
	EOF
	# shellcheck disable=SC2046
	eval export $(cd "$BSDSRCDIR" && make -f Makefile.cross \
		      "TARGET=${TARGET}" "CROSSDIR=${CROSSDIR}" cross-env)
	;;
*)
	TARGET="$(machine)"
	;;
esac

cd "${BSDSRCDIR}/sys/arch/${TARGET}/compile/${KERNEL}"

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

case "$_MODE" in
robsd-cross)	exit 0;;
*)		;;
esac

make install
