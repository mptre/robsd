. "${EXECDIR}/util.sh"

PATH="${PATH}:${CHROOT}${PORTSDIR}/infrastructure/bin" proot -c /dev/stdin <<-EOF
chroot=${CHROOT}
PORT_USER=${PORTSUSER}
actions=unpopulate
EOF

cat <<-EOF >"${CHROOT}/etc/doas.conf"
permit nopass keepenv root
EOF

chroot "$CHROOT" sh -x <<EOF
make -C "$PORTSDIR" fix-permissions
EOF
