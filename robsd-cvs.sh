. "${EXECDIR}/util.sh"
. "${EXECDIR}/util-ports.sh"
. "${EXECDIR}/util-regress.sh"

config_load <<'EOF'
ROBSDDIR="${robsddir}"
BUILDDIR="${builddir}"
CVSROOT="${cvs-root}"
CVSUSER="${cvs-user}"
TMPDIR="${tmp-dir}"
EOF

if [ -z "${CVSROOT}" ] || [ -z "${CVSUSER}" ]; then
	exit 0
fi

case "${_MODE}" in
robsd)
	config_load <<-'EOF'
	BSDSRCDIR="${bsd-srcdir}"
	XSRCDIR="${x11-srcdir}"
	EOF
	;;
robsd-ports)
	config_load <<-'EOF'
	CHROOT="${chroot}"
	PORTSDIR="${ports-dir}"
	EOF
	;;
robsd-regress)
	config_load <<-'EOF'
	BSDSRCDIR="${bsd-srcdir}"
	EOF
	;;
*)
	exit 1
	;;
esac

{
[ "${_MODE}" = "robsd" ] && echo src "${BSDSRCDIR}"
[ "${_MODE}" = "robsd" ] && echo xenocara "${XSRCDIR}"
[ "${_MODE}" = "robsd-ports" ] && echo ports "${CHROOT}${PORTSDIR}"
[ "${_MODE}" = "robsd-regress" ] && echo src "${BSDSRCDIR}"
} | while read -r _m _d; do
	_ci="${TMPDIR}/cvs-${_m}-ci.log"
	_up="${TMPDIR}/cvs-${_m}-up.log"

	if ! [ -d "${_d}/CVS" ]; then
		unpriv "${CVSUSER}" <<-EOF 2>&1 | tee "${_up}"
		cd ${_d}/..
		exec cvs -qd ${CVSROOT} checkout -P -d ${_d##*/} ${_m}
		EOF

		# Cannot compute CVS delta on checkout.
		: >"${_ci}"
	else
		unpriv "${CVSUSER}" "cd ${_d} && exec cvs -qd ${CVSROOT} update -Pd" 2>&1 |
		tee "${_up}" |
		cvs_log -t "${TMPDIR}/cvs-${_m}" -c "${_d}" -h "${CVSROOT}" -u "${CVSUSER}" |
		tee "${_ci}"
	fi

	find "${_d}" -type f -name Root -delete
done
