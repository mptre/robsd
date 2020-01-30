. "${EXECDIR}/util.sh"

for _diff in $BSDDIFF; do
	cd "$(diff_root -d "$BSDSRCDIR" "$_diff")"
	su "$CVSUSER" -c "patch -Cfs" <"$_diff"
	su "$CVSUSER" -c "patch -Es" <"$_diff"
done

for _diff in $XDIFF; do
	cd "$(diff_root -d "$XSRCDIR" "$_diff")"
	su "$CVSUSER" -c "patch -Cfs" <"$_diff"
	su "$CVSUSER" -c "patch -Es" <"$_diff"
done
