. "${EXECDIR}/util.sh"

# Prevent picking up compiler flags in bsd.sys.mk.
unset DESTDIR

regress_parallel "$1" || unset MAKEFLAGS
if regress_root "$1"; then
	unset SUDO
	exec make -C "${BSDSRCDIR}/regress/${1}"
else
	unpriv "$REGRESSUSER" "exec make -C ${BSDSRCDIR}/regress/${1}"
fi
