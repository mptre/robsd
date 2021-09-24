. "${EXECDIR}/util.sh"

# XXX
#rm -rf ${CHROOT}${PORTSDIR}/packages/*
#rm -rf ${CHROOT}${PORTSDIR}/distfiles/*
#rm -rf ${CHROOT}${PORTSDIR}/plist/*
#rm -rf ${CHROOT}${PORTSDIR}/pobj/*

PATH="${PATH}:$(ports_path)" proot -c /dev/stdin <<-EOF
chroot=${CHROOT}
PORT_USER=${PORTSUSER}
extra=/etc/installurl
actions=unpopulate
EOF

# XXX figure out what we need to rebuild, must happen above us in order to
# filter PORTS. pkg_outdated can fail if the chroot is not bootstraped yet,
# build everything then.
chroot "$CHROOT" sh -x <<EOF
PATH="${PATH}:$(ports_path -C)"
pkg_outdated
EOF

cat <<-EOF >"${CHROOT}/etc/doas.conf"
permit nopass keepenv root
EOF

chroot "$CHROOT" sh -x <<EOF
make -C "$PORTSDIR" fix-permissions
EOF

# XXX pkg_info -z | xargs -rt pkg_delete
