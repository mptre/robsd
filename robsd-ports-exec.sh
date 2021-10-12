. "${EXECDIR}/util.sh"

chroot "$CHROOT" sh -esux -- "$1" <<'EOF'

dependency() {
	case "$PORTS" in
	*${1}*)	return 1;;
	*)	return 0;;
	esac
}

PROGRESS_METER=No; export PROGRESS_METER

_make="env "SUBDIR=${1}" make -C ${PORTSDIR}"

# Reuse already built dependencies.
dependency "$1" || $_make clean=all
$_make package
$_make install
EOF

[ -n "$SIGNIFY" ] || exit 0

_pkgfile="$(chroot "$CHROOT" env "SUBDIR=${1}" make -C "$PORTSDIR" show=PKGFILE | grep -v '^===> ')"
cd "${CHROOT}${_pkgfile%/*}"
pkg_sign -s signify2 -s "$SIGNIFY" "${_pkgfile##*/}"
