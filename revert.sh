[ -e "${LOGDIR}/src.diff" ] || exit 0

(cd "$BSDSRCDIR" && patch -ERs) <"${LOGDIR}/src.diff"
find "$BSDSRCDIR" -type f -name '*.orig' -o -name '*.rej' | xargs -rt rm
