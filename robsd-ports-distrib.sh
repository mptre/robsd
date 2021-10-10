. "${EXECDIR}/util.sh"

set -o pipefail

if [ -z "$DISTRIBHOST" ] || [ -z "$DISTRIBPATH" ] || [ -z "$DISTRIBUSER" ]; then
	exit 0
fi

echo "$PORTS" |
chroot "$CHROOT" env SUBDIRLIST=/dev/stdin make -C "$PORTSDIR" run-dir-depends |
tsort |
chroot "$CHROOT" env SUBDIRLIST=/dev/stdin make -C "$PORTSDIR" show=PKGFILES |
grep -v '^===> ' |
xargs printf "${CHROOT}%s\n" |
sort |
tee "${BUILDDIR}/tmp/distrib" |
xargs sha256 |
sed -e 's,(.*/,(,' >"${BUILDDIR}/tmp/SHA256"

if [ -n "$SIGNIFY" ]; then
	signify -Se -s "$SIGNIFY" -m "${BUILDDIR}/tmp/SHA256"
fi

xargs ls -nT <"${BUILDDIR}/tmp/distrib" |
sed -e 's,/.*/,,' >"${BUILDDIR}/tmp/index.txt"

unpriv "$DISTRIBUSER" <<EOF
ssh -n ${DISTRIBHOST} rm -f ${DISTRIBPATH}/*
cd ${BUILDDIR}/tmp
scp -p \$(<distrib) SHA256* index.txt ${DISTRIBHOST}:${DISTRIBPATH}
EOF
