[ -z "$DIFF" ] && exit 0

cp "$DIFF" "${LOGDIR}/src.diff"
(cd "$BSDSRCDIR" && patch -E) <"$DIFF"
