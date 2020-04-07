. "${EXECDIR}/util.sh"

for _diff in $BSDDIFF; do
	cd "$(diff_root -d "$BSDSRCDIR" "$_diff")"
	su "$CVSUSER" -c "exec patch -Cfs" <"$_diff"
	su "$CVSUSER" -c "exec patch -Es" <"$_diff"
done

for _diff in $XDIFF; do
	cd "$(diff_root -d "$XSRCDIR" "$_diff")"
	su "$CVSUSER" -c "exec patch -Cfs" <"$_diff"
	su "$CVSUSER" -c "exec patch -Es" <"$_diff"
done
