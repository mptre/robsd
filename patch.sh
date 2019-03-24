. "${EXECDIR}/util.sh"

if [ -n "$SRCDIFF" ]; then
	cd "$(diff_root -f "$BSDSRCDIR" -r src "$SRCDIFF")"
	patch -Es <"$SRCDIFF"
fi

if [ -n "$X11DIFF" ]; then
	cd "$(diff_root -f "$X11SRCDIR" -r xenocara "$X11DIFF")"
	patch -Es <"$X11DIFF"
fi
