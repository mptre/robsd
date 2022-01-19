. "${EXECDIR}/util.sh"

_tmpdir="${BUILDDIR}/tmp"

case "$_MODE" in
robsd)
	for _diff in $BSDDIFF; do
		diff_apply -d "$BSDSRCDIR" -t "$_tmpdir" -u "$CVSUSER" "$_diff"
	done
	for _diff in $XDIFF; do
		diff_apply -d "$XSRCDIR" -t "$_tmpdir" -u "$CVSUSER" "$_diff"
	done
	;;
robsd-ports)
	for _diff in $PORTSDIFF; do
		diff_apply -d "${CHROOT}${PORTSDIR}" -t "$_tmpdir" \
			-u "$CVSUSER" "$_diff"
	done
	;;
robsd-regress)
	for _diff in $BSDDIFF; do
		diff_apply -d "$BSDSRCDIR" -t "$_tmpdir" -u "$CVSUSER" "$_diff"
	done
	;;
*)
	exit 1
	;;
esac
