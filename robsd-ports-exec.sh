. "${EXECDIR}/util.sh"

chroot "$CHROOT" sh -ex <<EOF
PROGRESS_METER=No; export PROGRESS_METER
cd "${PORTSDIR}/${1}" 2>/dev/null || cd "${PORTSDIR}/mystuff/${1}"
make install-depends
# Force build instead of trying to fetch the package.
make package FETCH_PACKAGES=No
make install
EOF
