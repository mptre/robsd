portable no

if testcase "canvas"; then
	_builddir="${TSHDIR}/2022-10-25.1"
	mkdir -p "${_builddir}"
	{
		step_serialize -s 1 -n first -l first.log -u me
	} >"$(step_path "${_builddir}")"

	assert_eq "me" "$(setmode "canvas" && report_receiver -b "${_builddir}")"
fi

if testcase "robsd"; then
	assert_eq "root" "$(setmode "robsd" && report_receiver -b "/var/empty")"
fi
