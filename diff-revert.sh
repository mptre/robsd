[ -e "${LOGDIR}/src.diff" ] || exit 0

(cd "$BSDSRCDIR" && patch -ER) <"${LOGDIR}/src.diff"
