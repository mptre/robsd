. "${EXECDIR}/util.sh"

if [ -n "$SRCDIFF" ]; then
	cd "$(diff_root -f "$BSDSRCDIR" -r src "$SRCDIFF")"
	su "$CVSUSER" -c "patch -ERs" <"$SRCDIFF"
	diff_clean "$BSDSRCDIR"
fi

if [ -n "$XDIFF" ]; then
	cd "$(diff_root -f "$XSRCDIR" -r xenocara "$XDIFF")"
	su "$CVSUSER" -c "patch -ERs" <"$XDIFF"
	diff_clean "$XSRCDIR"
fi
