. "${EXECDIR}/util.sh"

_tmpdir="${BUILDDIR}/tmp"

case "$_MODE" in
robsd)
	diff_list "$BUILDDIR" "src.diff" |
	diff_revert -d "$BSDSRCDIR" -t "$_tmpdir"

	diff_list "$BUILDDIR" "xenocara.diff" |
	diff_revert -d "$XSRCDIR" -t "$_tmpdir"
	;;
robsd-ports)
	diff_list "$BUILDDIR" "ports.diff" |
	diff_revert -d "${CHROOT}${PORTSDIR}" -t "$_tmpdir"
	;;
robsd-regress)
	diff_list "$BUILDDIR" "src.diff" |
	diff_revert -d "$BSDSRCDIR" -t "$_tmpdir"
	;;
*)
	exit 1
	;;
esac
