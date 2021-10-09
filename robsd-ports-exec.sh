. "${EXECDIR}/util.sh"

chroot "$CHROOT" sh -esux -- "$1" <<'EOF'

dependency() {
	case "$PORTS" in
	*${1}*)	return 1;;
	*)	return 0;;
	esac
}

PROGRESS_METER=No; export PROGRESS_METER

cd "$PORTSDIR"

_d="$(env "SUBDIR=${1}" make show=.CURDIR | grep -v '^===> ')"
cd "$_d"

# Reuse already built dependencies.
dependency "$1" || make clean=all
make package
make install
EOF

[ -n "$SIGNIFY" ] || exit 0

_pkgfile="$(chroot "$CHROOT" env "SUBDIR=${1}" make -C "$PORTSDIR" show=PKGFILE | grep -v '^===> ')"
cd "${CHROOT}${_pkgfile%/*}"
pkg_sign -s signify2 -s "$SIGNIFY" "${_pkgfile##*/}"
