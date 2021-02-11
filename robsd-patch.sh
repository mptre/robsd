. "${EXECDIR}/util.sh"

for _diff in $BSDDIFF; do
	cd "$(diff_root -d "$BSDSRCDIR" "$_diff")"
	diff_apply -u "$CVSUSER" "$_diff"
done

for _diff in $XDIFF; do
	cd "$(diff_root -d "$XSRCDIR" "$_diff")"
	diff_apply -u "$CVSUSER" "$_diff"
done
