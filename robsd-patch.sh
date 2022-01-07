. "${EXECDIR}/util.sh"

case "$_MODE" in
robsd)
	for _diff in $BSDDIFF; do
		cd "$(diff_root -d "$BSDSRCDIR" "$_diff")"
		diff_apply -u "$CVSUSER" "$_diff"
	done
	for _diff in $XDIFF; do
		cd "$(diff_root -d "$XSRCDIR" "$_diff")"
		diff_apply -u "$CVSUSER" "$_diff"
	done
	;;
robsd-ports)
	for _diff in $PORTSDIFF; do
		cd "$(diff_root -d "${CHROOT}${PORTSDIR}" "$_diff")"
		diff_apply -u "$CVSUSER" "$_diff"
	done
	;;
robsd-regress)
	for _diff in $BSDDIFF; do
		cd "$(diff_root -d "$BSDSRCDIR" "$_diff")"
		diff_apply -u "$CVSUSER" "$_diff"
	done
	;;
*)
	exit 1
	;;
esac
