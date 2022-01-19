. "${EXECDIR}/util.sh"

_tmpdir="${BUILDDIR}/tmp"

case "$_MODE" in
robsd)
	diff_list "$BUILDDIR" "src.diff" |
	while read -r _diff; do
		diff_revert -d "$BSDSRCDIR" -t "$_tmpdir" -u "$CVSUSER" "$_diff"
	done

	diff_list "$BUILDDIR" "xenocara.diff" |
	while read -r _diff; do
		diff_revert -d "$XSRCDIR" -t "$_tmpdir" -u "$CVSUSER" "$_diff"
	done
	;;
robsd-ports)
	diff_list "$BUILDDIR" "ports.diff" |
	while read -r _diff; do
		diff_revert -d "${CHROOT}${PORTSDIR}" -t "$_tmpdir" -u "$CVSUSER" "$_diff"
	done
	;;
robsd-regress)
	diff_list "$BUILDDIR" "src.diff" |
	while read -r _diff; do
		diff_revert -d "$BSDSRCDIR" -t "$_tmpdir" -u "$CVSUSER" "$_diff"
	done
	;;
*)
	exit 1
	;;
esac
