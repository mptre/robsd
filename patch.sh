. "${EXECDIR}/util.sh"

if [ -n "$SRCDIFF" ]; then
	cd "$(diff_root -f "$BSDSRCDIR" -r src "$SRCDIFF")"
	su "$CVSUSER" -c "patch -Cs" <"$SRCDIFF"
	su "$CVSUSER" -c "patch -Es" <"$SRCDIFF"
fi

if [ -n "$XDIFF" ]; then
	cd "$(diff_root -f "$XSRCDIR" -r xenocara "$XDIFF")"
	su "$CVSUSER" -c "patch -Cs" <"$XDIFF"
	su "$CVSUSER" -c "patch -Es" <"$XDIFF"
fi
