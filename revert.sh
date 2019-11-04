. "${EXECDIR}/util.sh"

if [ -n "$SRCDIFF" ]; then
	cd "$(diff_root -d "$BSDSRCDIR" "$SRCDIFF")"
	su "$CVSUSER" -c "patch -ERs" <"$SRCDIFF"
	diff_clean "$BSDSRCDIR"
fi

if [ -n "$XDIFF" ]; then
	cd "$(diff_root -d "$XSRCDIR" "$XDIFF")"
	su "$CVSUSER" -c "patch -ERs" <"$XDIFF"
	diff_clean "$XSRCDIR"
fi
