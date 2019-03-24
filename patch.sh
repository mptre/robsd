. "${EXECDIR}/util.sh"

if [ -n "$SRCDIFF" ]; then
	cd "$(diff_root -f "$BSDSRCDIR" "$SRCDIFF")"
	patch -Es <"$SRCDIFF"
fi
