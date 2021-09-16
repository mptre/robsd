. "${EXECDIR}/util.sh"

# Prevent picking up compiler flags in bsd.sys.mk.
unset DESTDIR
regress_parallel "$1" || unset MAKEFLAGS
unpriv "$REGRESSUSER" "exec make -C ${BSDSRCDIR}/regress/${1}"
