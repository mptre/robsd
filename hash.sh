. "${EXECDIR}/util.sh"

RELDIR="$(release_dir "$LOGDIR")"
RELXDIR="$(release_dir -x "$LOGDIR")"

if [ -e "${RELXDIR}/SHA256" ]; then
	cat "${RELXDIR}/SHA256" >>"${RELDIR}/SHA256"
	rm "${RELXDIR}/SHA256"
fi

if [ -d "$RELXDIR" ]; then
	find "$RELXDIR" -type f -exec mv {} "$RELDIR" \;
	rm -r "$RELXDIR"
fi

# Compute missing SHA for install*.{img,iso}.
cd "$RELDIR"
mv SHA256 SHA256.orig
{ grep -v 'install.*' SHA256.orig; sha256 install*; } | sort >SHA256
rm SHA256.orig
