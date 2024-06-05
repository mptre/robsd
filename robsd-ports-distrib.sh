. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-ports.sh"

set -o pipefail

config_load <<-'EOF'
CHROOT="${chroot}"
DISTRIBHOST="${distrib-host}"
DISTRIBPATH="${distrib-path}"
DISTRIBUSER="${distrib-user}"
PORTSDIR="${ports-dir}"
SIGNIFY="${distrib-signify}"
TMPDIR="${tmp-dir}"
EOF

if [ -z "${DISTRIBHOST}" ] || [ -z "${DISTRIBPATH}" ] || [ -z "${DISTRIBUSER}" ]; then
	exit 0
fi

chroot "${CHROOT}" env SUBDIRLIST=/dev/stdin make -C "${PORTSDIR}" run-dir-depends <"${TMPDIR}/ports" |
tsort |
chroot "${CHROOT}" env SUBDIRLIST=/dev/stdin make -C "${PORTSDIR}" show=PKGFILES |
grep -v '^===> ' |
xargs printf "${CHROOT}%s\n" |
sort >"${TMPDIR}/distrib"

if [ -n "${SIGNIFY}" ]; then
	# By default pkg_sign(1) writes out the signed package to the current
	# directory, hence the cd.
	xargs -I{} sh -c "cd {}/.. && pkg_sign -s signify2 -s ${SIGNIFY} {}" \
		<"${TMPDIR}/distrib"
fi

xargs sha256 <"${TMPDIR}/distrib" |
sed -e 's,(.*/,(,' >"${TMPDIR}/SHA256"

if [ -n "${SIGNIFY}" ]; then
	signify -Se -s "${SIGNIFY}" -m "${TMPDIR}/SHA256"
fi

xargs ls -nT <"${TMPDIR}/distrib" |
sed -e 's,/.*/,,' >"${TMPDIR}/index.txt"

unpriv "${DISTRIBUSER}" <<EOF
ssh -n ${DISTRIBHOST} rm -f ${DISTRIBPATH}/*
cd ${TMPDIR}
scp -p \$(<distrib) SHA256* index.txt ${DISTRIBHOST}:${DISTRIBPATH}
EOF
