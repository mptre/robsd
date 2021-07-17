. "${EXECDIR}/util.sh"

regress_parallel "$1" || unset MAKEFLAGS
unpriv "$REGRESSUSER" "exec make -C ${BSDSRCDIR}/regress/${1}"
