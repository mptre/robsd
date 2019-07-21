. "${EXECDIR}/util.sh"

if [ -n "$SRCDIFF" ]; then
	cd "$(diff_root -f "$BSDSRCDIR" -r src "$SRCDIFF")"
	su "$CVSUSER" -c "patch -Cs" <"$SRCDIFF"
	su "$CVSUSER" -c "patch -Es" <"$SRCDIFF"
fi

if [ -n "$X11DIFF" ]; then
	cd "$(diff_root -f "$X11SRCDIR" -r xenocara "$X11DIFF")"
	su "$CVSUSER" -c "patch -Cs" <"$X11DIFF"
	su "$CVSUSER" -c "patch -Es" <"$X11DIFF"
fi
