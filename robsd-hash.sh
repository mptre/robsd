. "${EXECDIR}/util.sh"

RELDIR="$(release_dir "$BUILDDIR")"
RELXDIR="$(release_dir -x "$BUILDDIR")"

if [ -e "${RELXDIR}/SHA256" ]; then
	cat "${RELXDIR}/SHA256" >>"${RELDIR}/SHA256"
	rm "${RELXDIR}/SHA256"
fi

if [ -d "$RELXDIR" ]; then
	find "$RELXDIR" -type f -exec mv {} "$RELDIR" \;
	rm -r "$RELXDIR"
fi

cd "$RELDIR"

{
	# Set the date to the start of the build.
	date -u -r "$(build_date)" "+Build date: %s - %+"
	# Include date of the last CVS revision.
	for _dir in "$BUILDDIR" $(prev_release 0); do
		_date="$(cvs_date "$_dir")" || continue
		date -u -r "$_date" "+Build cvs date: %s - %+"
		break
	done
	echo "Build id: ${BUILDDIR##*/}"
} >BUILDINFO

# Compute missing checksums.
mv SHA256 SHA256.orig
{
	grep -v -e 'install.*' -e BUILDINFO SHA256.orig
	sha256 install* BUILDINFO
} | sort >SHA256
rm SHA256.orig
