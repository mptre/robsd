. "${EXECDIR}/util.sh"

if [ -z "$DISTRIBHOST" ] || [ -z "$DISTRIBPATH" ] || [ -z "$DISTRIBUSER" ]; then
	exit 0
fi

# XXX debug packages included?
# XXX use SUBDIRLIST?
# Use echo to normalize whitespace.
# shellcheck disable=SC2086,SC2116
_subdir="$(echo $PORTS)"
chroot "$CHROOT" env "SUBDIR=${_subdir}" make -C "$PORTSDIR" show=PKGFILE |
grep '^/' |
xargs printf "${CHROOT}%s\n" |
tee "${BUILDDIR}/tmp/distrib" |
xargs sha256 |
sed -e 's,(.*/,(,' |
sort >"${BUILDDIR}/tmp/SHA256"

if [ -n "$SIGNIFY" ]; then
	signify -Se -s "$SIGNIFY" -m SHA256
fi

ls -nT -- * >"${BUILDDIR}/tmp/index.txt"

unpriv "$DISTRIBUSER" "exec ssh ${DISTRIBHOST} rm -f ${DISTRIBPATH}/*"
unpriv "$DISTRIBUSER" "exec scp -p $(cat "${BUILDDIR}/tmp/distrib") ${BUILDDIR}/tmp/SHA256* ${BUILDDIR}/tmp/index.txt ${DISTRIBHOST}:${DISTRIBPATH}"

exit 1
