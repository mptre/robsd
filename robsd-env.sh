. "${EXECDIR}/util.sh"

sysctl -n kern.version
printenv | sort
df -h
