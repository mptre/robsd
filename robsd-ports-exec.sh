. "${EXECDIR}/util.sh"

chroot "$CHROOT" sh -esux -- "$1" <<'EOF'
PROGRESS_METER=No; export PROGRESS_METER

_make="env "SUBDIR=${1}" make -C ${PORTSDIR}"
$_make clean=all
$_make package
$_make install
EOF

[ -n "$SIGNIFY" ] || exit 0

# By default pkg_sign(1) writes out the signed package to the current directory,
# hence the cd.
chroot "$CHROOT" env "SUBDIR=${1}" make -C "$PORTSDIR" show=PKGFILES |
grep -v '^===> ' |
xargs printf "${CHROOT}%s\n" |
xargs -t -I{} sh -c "cd {}/.. && pkg_sign -s signify2 -s ${SIGNIFY} {}"
