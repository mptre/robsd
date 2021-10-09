. "${EXECDIR}/util.sh"

set -o pipefail

chroot "$CHROOT" sh -ex <<'EOF' | tsort -r >"${BUILDDIR}/tmp/outdated"
cd $PORTSDIR

_DEPENDS_CACHE=$(make create_DEPENDS_CACHE); export _DEPENDS_CACHE

for _p in $PORTS; do
	_pkgfile="$(env "SUBDIR=${_p}" make show=PKGFILE | grep -v '^===> ')"
	if [ -e $_pkgfile ]; then
		_s1=$(pkg_info -S -Dunsigned $_pkgfile 2>&1 | sed -n -e 's/Signature: //p')
		_s2="$(env "SUBDIR=${_p}" make print-update-signature | grep -v '^===> ')"
		[ "$_s1" = "$_s2" ] && continue
	fi

	env "SUBDIR=${_p}" make all-dir-depends
done

make destroy_DEPENDS_CACHE
EOF
