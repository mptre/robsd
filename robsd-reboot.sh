. "${EXECDIR}/util.sh"

config_load <<-'EOF'
BUILDDIR="${builddir}"
REBOOT="${reboot}"
EOF

[ "$REBOOT" -eq 1 ] || exit 0

cat <<-EOF >>/etc/rc.firsttime
/usr/local/sbin/robsd -r ${BUILDDIR} >/dev/null
EOF

# Add some grace in order to let the script finish.
shutdown -r '+1' </dev/null >/dev/null 2>&1
