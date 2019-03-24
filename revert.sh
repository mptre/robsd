. "${EXECDIR}/util.sh"

[ -z "$SRCDIFF" ] && exit 0

SRCDIR="$(diff_root -f "$BSDSRCDIR" "$SRCDIFF")"
(cd "$SRCDIR" && patch -ERs) <"$SRCDIFF"
find "$BSDSRCDIR" -type f \( -name '*.orig' -o -name '*.rej' \) |
xargs -rt rm
