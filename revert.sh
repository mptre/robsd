. "${EXECDIR}/util.sh"

diff_clean() {
	find "$1" -type f \( -name '*.orig' -o -name '*.rej' \) |
	xargs -rt rm
}

if [ -n "$SRCDIFF" ]; then
	cd "$(diff_root -f "$BSDSRCDIR" -r src "$SRCDIFF")"
	patch -ERs <"$SRCDIFF"
	diff_clean "$BSDSRCDIR"
fi

if [ -n "$X11DIFF" ]; then
	cd "$(diff_root -f "$X11SRCDIR" -r xenocara "$X11DIFF")"
	patch -ERs <"$X11DIFF"
	diff_clean "$X11SRCDIR"
fi
