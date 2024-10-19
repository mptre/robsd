portable no

. "${EXECDIR}/util-regress.sh"

_builddir="${TSHDIR}/2024-10-19.1"

if testcase "robsd-regress: timeout"; then
	mkdir -p "${_builddir}/tmp"
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "test/timeout" root
	EOF
	echo "${_builddir}" >"${TSHDIR}/.running"
	mkdir -p "${TSHDIR}/regress/test/timeout"
	cat <<EOF >>"${TSHDIR}/regress/test/timeout/Makefile"
regress:
	sleep 5
EOF
	cat <<-EOF >"${_builddir}/timeout.log"
==== timeout ====
	EOF

	_err=0
	(
		setmode robsd-regress &&
		DETACH=0 ROBSDEXEC="${ROBSDEXEC} -T" \
			step_exec -l "${_builddir}/timeout.log" -s test/timeout
	) >/dev/null || _err="$?"
	if [ "${_err}" -ne 124 ]; then
		fail "expected exit timeout, got ${_err}"
	fi
fi
