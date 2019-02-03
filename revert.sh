. "${EXECDIR}/util.sh"

[ -z "$DIFF" ] && exit 0

SRCDIR="$(diff_root "$DIFF")"
[ -z "$SRCDIR" ] && SRCDIR="$BSDSRCDIR"
(cd "$SRCDIR" && patch -ERs) <"$DIFF"
find "$BSDSRCDIR" -print0 -type f -name '*.orig' -o -name '*.rej' |
	xargs -0rt rm
