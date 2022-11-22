if testcase "basic"; then
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	_builddir="${TSHDIR}/2022-11-21"
	echo "$_builddir" >"${TSHDIR}/.running"
	mkdir "$_builddir"
	mkdir "$(release_dir "$_builddir")" "$(release_dir -x "$TSHDIR")"
	: >"$(release_dir "$_builddir")/SHA256"
	{
		step_serialize -s 1 -n env -t 1666666666
		step_serialize -H -s 2 -n cvs -t 1666666666
	} >"$(step_path "$_builddir")"

	_err=0
	env "BUILDDIR=${_builddir}" sh -eux -o pipefail \
		"${EXECDIR}/robsd-hash.sh" >"$TMP1" 2>&1 || _err="$?"
	if [ "$_err" -ne 0 ]; then
		fail - "expected exit zero" <"$TMP1"
	fi

	assert_file - "${_builddir}/rel/BUILDINFO" <<-EOF
	Build date: 1666666666 - Tue Oct 25 02:57:46 UTC 2022
	Build cvs date: 1666666666 - Tue Oct 25 02:57:46 UTC 2022
	Build id: 2022-11-21
	EOF
	assert_file - "${_builddir}/rel/SHA256" <<-EOF
	SHA256 (BUILDINFO) = 5aaf0bbaacc7d0ae26e9d75b4c61dc1f5234e4e46738337755c20bd1edf792b6
	EOF
fi
