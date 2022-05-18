. "${EXECDIR}/util.sh"

sysctl -n kern.version
printenv | sort
df -h

case "$_MODE" in
robsd-regress)	regress_dump;;
*)		;;
esac
