. "${EXECDIR}/util.sh"

for _diff in $SRCDIFF; do
	cd "$(diff_root -d "$BSDSRCDIR" "$_diff")"
	su "$CVSUSER" -c "patch -ERs" <"$_diff"
done
if [ -n "$SRCDIFF" ]; then
	diff_clean "$BSDSRCDIR"
fi

for _diff in $XDIFF; do
	cd "$(diff_root -d "$XSRCDIR" "$_diff")"
	su "$CVSUSER" -c "patch -ERs" <"$_diff"
done
if [ -n "$XDIFF" ]; then
	diff_clean "$XSRCDIR"
fi
