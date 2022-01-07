. "${EXECDIR}/util.sh"

case "$_MODE" in
robsd)
	# shellcheck disable=SC2046
	diff_revert "$BSDSRCDIR" $(diff_list "$BUILDDIR" "src.diff")
	# shellcheck disable=SC2046
	diff_revert "$XSRCDIR" $(diff_list "$BUILDDIR" "xenocara.diff")
	;;
robsd-ports)
	# shellcheck disable=SC2046
	diff_revert "${CHROOT}${PORTSDIR}" $(diff_list "$BUILDDIR" "ports.diff")
	;;
robsd-regress)
	# shellcheck disable=SC2046
	diff_revert "$BSDSRCDIR" $(diff_list "$BUILDDIR" "src.diff")
	;;
*)
	exit 1
	;;
esac
