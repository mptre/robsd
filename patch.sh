. "${EXECDIR}/util.sh"

if [ -n "$SRCDIFF" ]; then
	cd "$(diff_root -d "$BSDSRCDIR" "$SRCDIFF")"
	su "$CVSUSER" -c "patch -Cs" <"$SRCDIFF"
	su "$CVSUSER" -c "patch -Es" <"$SRCDIFF"
fi

if [ -n "$XDIFF" ]; then
	cd "$(diff_root -d "$XSRCDIR" "$XDIFF")"
	su "$CVSUSER" -c "patch -Cs" <"$XDIFF"
	su "$CVSUSER" -c "patch -Es" <"$XDIFF"
fi
