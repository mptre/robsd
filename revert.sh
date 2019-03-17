. "${EXECDIR}/util.sh"

[ -z "$DIFF" ] && exit 0

SRCDIR="$(diff_root "$DIFF")"
(cd "$SRCDIR" && patch -ERs) <"$DIFF"
find "$BSDSRCDIR" -type f \( -name '*.orig' -o -name '*.rej' \) |
xargs -rt rm
