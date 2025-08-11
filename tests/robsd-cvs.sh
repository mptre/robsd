portable no

_robsddir="${TSHDIR}/robsd"
_builddir="${_robsddir}/2025-07-22"
_step="${EXECDIR}/robsd-cvs.sh"

setup() {
	robsd_config - <<-EOF
	robsddir "${_robsddir}"
	EOF
	mkdir "${_robsddir}"
	echo "${_builddir}" >"${_robsddir}/.running"
	mkdir -p "${_builddir}/tmp" "${TSHDIR}/CVS"

	cat <<-EOF >"${TSHDIR}/su"
	sleep .5
	echo cvs start
	echo cvs stop
	EOF
	chmod u+x "${TSHDIR}/su"
}

if testcase "previous cvs date absent"; then
	(PATH="${TSHDIR}:${PATH}" robsd_step_exec -m robsd "${_step}")

	assert_file - "${_builddir}/tmp/cvs-src-up.log" <<-EOF
	cvs start
	cvs stop
	EOF
fi
