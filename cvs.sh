for d in "$BSDSRCDIR" "$X11SRCDIR"; do
	su "$CVSUSER" -c "cd ${d} && cvs -q -d ${CVSROOT} update -Pd"
	find "${d}" -type f -name Root -exec rm {} \;
done
