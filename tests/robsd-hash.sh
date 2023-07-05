portable no

_step="${EXECDIR}/robsd-hash.sh"

if testcase "basic"; then
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	_builddir="${TSHDIR}/2022-11-21"
	echo "$_builddir" >"${TSHDIR}/.running"
	mkdir "$_builddir" "${_builddir}/tmp" "${_builddir}/rel" \
		"${_builddir}/relx"
	: >"${_builddir}/rel/SHA256"
	{
		step_serialize -s 1 -n env -t 1666666666
		step_serialize -H -s 2 -n cvs -t 1666666666
	} >"$(step_path "$_builddir")"
	echo "P bin/ksh/ksh.c" >"${_builddir}/tmp/cvs-src-up.log"

	robsd_step_exec -m robsd "$_step"

	assert_file - "${_builddir}/rel/BUILDINFO" <<-EOF
	Build date: 1666666666 - Tue Oct 25 02:57:46 UTC 2022
	Build cvs date: 1666666666 - Tue Oct 25 02:57:46 UTC 2022
	Build id: 2022-11-21
	EOF
	assert_file - "${_builddir}/rel/SHA256" <<-EOF
	SHA256 (BUILDINFO) = 5aaf0bbaacc7d0ae26e9d75b4c61dc1f5234e4e46738337755c20bd1edf792b6
	SHA256 (CHANGELOG) = 4f1bd159434685a050e2536cabd34c8f2ede7750ea45d2588efe97fd5baa9a44
	EOF
fi

if testcase "previous cvs date"; then
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	_builddir="${TSHDIR}/2022-11-21"
	echo "$_builddir" >"${TSHDIR}/.running"
	mkdir "$_builddir" "${_builddir}/tmp" "${_builddir}/rel" \
		"${_builddir}/relx"
	: >"${_builddir}/rel/SHA256"
	step_serialize -s 1 -n env -t 1666666666 \
		>"$(step_path "$_builddir")"

	mkdir "${TSHDIR}/2022-11-20"
	step_serialize -s 1 -n cvs -t 1555555555 \
		>"$(step_path "${TSHDIR}/2022-11-20")"

	robsd_step_exec -m robsd "$_step"

	assert_file - "${_builddir}/rel/BUILDINFO" <<-EOF
	Build date: 1666666666 - Tue Oct 25 02:57:46 UTC 2022
	Build cvs date: 1555555555 - Thu Apr 18 02:45:55 UTC 2019
	Build id: 2022-11-21
	EOF
fi
