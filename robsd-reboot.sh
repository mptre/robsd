. "${EXECDIR}/util.sh"

if [ "$(config_value reboot)" -eq 0 ]; then
	exit 0
fi

cat <<-EOF >>/etc/rc.firsttime
/usr/local/sbin/robsd -r ${BUILDDIR} >/dev/null
EOF

# Add some grace in order to let the script finish.
shutdown -r '+1' </dev/null >/dev/null 2>&1
