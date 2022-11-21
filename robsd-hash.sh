. "${EXECDIR}/util.sh"

config_load <<'EOF'
ROBSDDIR="${robsddir}"
EOF

_reldir="$(release_dir "$BUILDDIR")"
_relxdir="$(release_dir -x "$BUILDDIR")"

if [ -e "${_relxdir}/SHA256" ]; then
	cat "${_relxdir}/SHA256" >>"${_reldir}/SHA256"
	rm "${_relxdir}/SHA256"
fi

if [ -d "$_relxdir" ]; then
	find "$_relxdir" -type f -exec mv {} "$_reldir" \;
	rm -r "$_relxdir"
fi

cd "$_reldir"

diff_list "$BUILDDIR" "*.diff" |
while read -r _f; do
	cp "$_f" .
done

{
	# Set the date to the start of the build.
	_date="$(build_date -b "$BUILDDIR")"
	date -u -r "$_date" "+Build date: %s - %+"
	# Include date of the last CVS revision.
	for _dir in "$BUILDDIR" $(prev_release -r "$ROBSDDIR" 0); do
		_date="$(cvs_date -b "$BUILDDIR" -s "$(step_path "$_dir")")" || continue
		date -u -r "$_date" "+Build cvs date: %s - %+"
		break
	done
	echo "Build id: ${BUILDDIR##*/}"
	if [ -e "${BUILDDIR}/tags" ]; then
		echo -n "Build tags: "
		xargs <"${BUILDDIR}/tags"
	fi

	if [ -e "${BUILDDIR}/comment" ]; then
		echo
		cat "${BUILDDIR}/comment"
	fi
} >BUILDINFO

# Compute missing checksums.
mv SHA256 SHA256.orig
{
	grep -v -e BUILDINFO -e 'install.*' -e '*.diff.*' SHA256.orig || :

	find . -type f \( -name 'BUILDINFO' -o -name 'install*' -name '*.diff.*' \) |
	sed -e 's,^\./,,' |
	xargs -rt sha256
} | sort >SHA256
rm SHA256.orig
