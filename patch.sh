. "${EXECDIR}/util.sh"

[ -z "$DIFF" ] && exit 0

[ -e "${LOGDIR}/src.diff" ] || cp "$DIFF" "${LOGDIR}/src.diff"

SRCDIR="$(diff_root "$DIFF")"
[ -z "$SRCDIR" ] && SRCDIR="$BSDSRCDIR"
(cd "$SRCDIR" && patch -Es) <"$DIFF"
