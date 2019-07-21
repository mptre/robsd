. "${EXECDIR}/util.sh"

for d in "$BSDSRCDIR" "$X11SRCDIR"; do
	# Temporary directory used while generating logs. Intentionally not
	# deleted in a trap handler since it's useful when something goes wrong.
	WRKDIR="$(mktemp -d -t robsd.XXXXXX)"

	su "$CVSUSER" -c "cd ${d} && cvs -q -d ${CVSROOT} update -Pd" |
		tee "${WRKDIR}/log"
	find "${d}" -type f -name Root -delete

	cvs_log -r "$d" -t "$WRKDIR" -u "$CVSUSER" <"${WRKDIR}/log"
done
