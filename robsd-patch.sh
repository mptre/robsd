. "${EXECDIR}/util.sh"

_tmpdir="${BUILDDIR}/tmp"

case "$_MODE" in
robsd)
	diff_list "$BUILDDIR" "src.diff" |
	while read -r _diff; do
		diff_apply -d "$BSDSRCDIR" -t "$_tmpdir" -u "$CVSUSER" "$_diff"
	done
	diff_list "$BUILDDIR" "xenocara.diff" |
	while read -r _diff; do
		diff_apply -d "$XSRCDIR" -t "$_tmpdir" -u "$CVSUSER" "$_diff"
	done
	;;
robsd-ports)
	diff_list "$BUILDDIR" "ports.diff" |
	while read -r _diff; do
		diff_apply -d "${CHROOT}${PORTSDIR}" -t "$_tmpdir" \
			-u "$CVSUSER" "$_diff"
	done
	;;
robsd-regress)
	diff_list "$BUILDDIR" "src.diff" |
	while read -r _diff; do
		diff_apply -d "$BSDSRCDIR" -t "$_tmpdir" -u "$CVSUSER" "$_diff"
	done
	;;
*)
	exit 1
	;;
esac
