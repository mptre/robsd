. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-regress.sh"

config_load <<'EOF'
BUILDDIR="${builddir}"
SUDO="${sudo}"
BSDSRCDIR="${bsd-srcdir}"
REGRESSUSER="${regress-user}"
EOF

_err=0
_env="REGRESS_FAIL_EARLY=no"
_env="${_env} $(config_value "regress-${1}-env" 2>/dev/null || :)"
_make="make -C ${BSDSRCDIR}/regress/${1} ${_env}"

for _target in $(config_value "regress-${1}-targets"); do
	if regress_root "$1"; then
		${_make} "${_target}" || _err=$?
	else
		export SUDO
		# Since we're most likely running as the build user, use a more
		# generous login class as some regression tests are resource
		# hungry.
		unpriv -c staff "${REGRESSUSER}" \
			"exec ${_make} ${_target}" || _err=$?
	fi
done

exit "${_err}"
