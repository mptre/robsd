. "${EXECDIR}/util.sh"

if [ -n "$SRCDIFF" ]; then
	cd "$(diff_root -f "$BSDSRCDIR" -r src "$SRCDIFF")"
	su "$CVSUSER" -c "patch -ERs" <"$SRCDIFF"
	diff_clean "$BSDSRCDIR"
fi

if [ -n "$X11DIFF" ]; then
	cd "$(diff_root -f "$X11SRCDIR" -r xenocara "$X11DIFF")"
	su "$CVSUSER" -c "patch -ERs" <"$X11DIFF"
	diff_clean "$X11SRCDIR"
fi
