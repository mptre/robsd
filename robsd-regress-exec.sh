. "${EXECDIR}/util.sh"

unpriv "$REGRESSUSER" "exec make -C ${BSDSRCDIR}/regress/${1}"
