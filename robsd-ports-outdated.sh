. "${EXECDIR}/util.sh"

chroot "$CHROOT" sh -ex <<'EOF' >"${BUILDDIR}/tmp/outdated.log"
cd $PORTSDIR
_DEPENDS_CACHE=$(make create_DEPENDS_CACHE); export _DEPENDS_CACHE

_arch=$(machine)

for _p in $PORTS; do
	cd ${PORTSDIR}/${_p} 2>/dev/null || cd ${PORTSDIR}/mystuff/${_p}

	_pkgfile="$(make show=PKGFILE)"
	if [ -e $_pkgfile ]; then
		_s1=$(pkg_info -S -Dunsigned $_pkgfile 2>&1 | sed -n -e 's/Signature: //p')
		_s2=$(make print-update-signature)
		[ "$_s1" = "$_s2" ] && continue
	fi

	# Capture the plist, later used to generate a diff.
	_pkgname=$(make show=FULLPKGNAME)
	_plist=$(make show=PLIST_REPOSITORY)/${_arch}/${_pkgname}
	cat  ${_plist} >/tmp/${_pkgname}.plist || :

	echo $_p
done

cd $PORTSDIR
make destroy_DEPENDS_CACHE
EOF
