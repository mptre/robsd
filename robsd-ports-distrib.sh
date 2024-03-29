. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-ports.sh"

set -o pipefail

config_load <<-'EOF'
BUILDDIR="${builddir}"
CHROOT="${chroot}"
DISTRIBHOST="${distrib-host}"
DISTRIBPATH="${distrib-path}"
DISTRIBUSER="${distrib-user}"
SIGNIFY="${distrib-signify}"
PORTSDIR="${ports-dir}"
EOF

if [ -z "$DISTRIBHOST" ] || [ -z "$DISTRIBPATH" ] || [ -z "$DISTRIBUSER" ]; then
	exit 0
fi

_tmpdir="${BUILDDIR}/tmp"

chroot "$CHROOT" env SUBDIRLIST=/dev/stdin make -C "$PORTSDIR" run-dir-depends <"${_tmpdir}/ports" |
tsort |
chroot "$CHROOT" env SUBDIRLIST=/dev/stdin make -C "$PORTSDIR" show=PKGFILES |
grep -v '^===> ' |
xargs printf "${CHROOT}%s\n" |
sort >"${_tmpdir}/distrib"

if [ -n "$SIGNIFY" ]; then
	# By default pkg_sign(1) writes out the signed package to the current
	# directory, hence the cd.
	xargs -I{} sh -c "cd {}/.. && pkg_sign -s signify2 -s ${SIGNIFY} {}" \
		<"${_tmpdir}/distrib"
fi

xargs sha256 <"${_tmpdir}/distrib" |
sed -e 's,(.*/,(,' >"${BUILDDIR}/tmp/SHA256"

if [ -n "$SIGNIFY" ]; then
	signify -Se -s "$SIGNIFY" -m "${BUILDDIR}/tmp/SHA256"
fi

xargs ls -nT <"${_tmpdir}/distrib" |
sed -e 's,/.*/,,' >"${BUILDDIR}/tmp/index.txt"

unpriv "$DISTRIBUSER" <<EOF
ssh -n ${DISTRIBHOST} rm -f ${DISTRIBPATH}/*
cd ${_tmpdir}
scp -p \$(<distrib) SHA256* index.txt ${DISTRIBHOST}:${DISTRIBPATH}
EOF
