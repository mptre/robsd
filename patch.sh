. "${EXECDIR}/util.sh"

if [ -n "$SRCDIFF" ]; then
	(cd "$(diff_root "$SRCDIFF")" && patch -Es) <"$SRCDIFF"
fi
