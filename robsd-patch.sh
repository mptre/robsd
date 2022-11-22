. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-ports.sh"
. "${EXECDIR}/util-regress.sh"

config_load <<-'EOF'
BUILDDIR="${builddir}"
EOF

_tmpdir="${BUILDDIR}/tmp"

case "$_MODE" in
robsd)
	config_load <<-'EOF'
	BSDSRCDIR="${bsd-srcdir}"
	CVSUSER="${cvs-user}"
	XSRCDIR="${x11-srcdir}"
	EOF

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
	config_load <<-'EOF'
	CHROOT="${chroot}"
	CVSUSER="${cvs-user}"
	PORTSDIR="${ports-dir}"
	EOF

	diff_list "$BUILDDIR" "ports.diff" |
	while read -r _diff; do
		diff_apply -d "${CHROOT}${PORTSDIR}" -t "$_tmpdir" \
			-u "$CVSUSER" "$_diff"
	done
	;;
robsd-regress)
	config_load <<-'EOF'
	BSDSRCDIR="${bsd-srcdir}"
	CVSUSER="${cvs-user}"
	EOF

	diff_list "$BUILDDIR" "src.diff" |
	while read -r _diff; do
		diff_apply -d "$BSDSRCDIR" -t "$_tmpdir" -u "$CVSUSER" "$_diff"
	done
	;;
*)
	exit 1
	;;
esac
