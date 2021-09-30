. "${EXECDIR}/util.sh"

chroot "$CHROOT" sh -esux -- "$1" <<'EOF'
PROGRESS_METER=No; export PROGRESS_METER

cd "${PORTSDIR}/${1}" 2>/dev/null || cd "${PORTSDIR}/mystuff/${1}"

make clean=all
make install-depends
# Force build instead of trying to fetch the package.
make package FETCH_PACKAGES=No
make install

# Generate plist diff, will end up in the report.
_pkgname=$(make show=FULLPKGNAME)
_plist=$(make show=PLIST_REPOSITORY)/$(machine)/${_pkgname}
set +x
diff -U0 -L PLIST.orig -L PLIST /tmp/${_pkgname}.plist ${_plist} || :
EOF
