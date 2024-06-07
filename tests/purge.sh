portable no

if testcase "basic"; then
	for _d in 2019-03-01 2019-03-02 2019-03-03; do
		mkdir -p "${TSHDIR}/${_d}/rel"
	done
	for _d in "${TSHDIR}"/*; do
		for _f in \
			01-base.log 01-base.log.1 03-env.log comment dmesg \
			rel/index.txt report stat.csv src.diff.1 tags
		do
			(cd "${_d}" && echo "${_f}" >"${_f}")
		done
		: >"$(step_path "${_d}")"
		mkdir "${_d}/tmp"
		touch "${_d}/tmp/cvs.log"
	done
	touch -t 201903012233.44 "${TSHDIR}/2019-03-01"
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF

	purge "${TSHDIR}" 2 >"${TMP1}"
	assert_file - "${TMP1}" <<-EOF
	${TSHDIR}/2019-03-01
	EOF

	[ -d "${TSHDIR}/attic/2019/03/01" ] ||
		fail "expected 2019-03-01 to be moved"
	[ -d "${TSHDIR}/2019-03-02" ] ||
		fail "expected 2019-03-02 to be left"
	[ -d "${TSHDIR}/2019-03-03" ] ||
		fail "expected 2019-03-03 to be left"

	(cd "${TSHDIR}/attic/2019/03/01" &&
	 find . -type f | sed -e 's,^\./,,' | sort) >"${TMP1}"
	assert_file - "${TMP1}" <<-EOF
	comment
	rel/index.txt
	report
	src.diff.1
	stat.csv
	step.csv
	tags
	EOF

	assert_eq "Mar  1 22:33:44 2019" \
		"$(stat -f '%Sm' "${TSHDIR}/attic/2019/03/01")"
fi

if testcase "missing log files"; then
	mkdir -p "${TSHDIR}/2019-03-01/rel" "${TSHDIR}/2019-03-02/rel"
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF

	assert_eq "${TSHDIR}/2019-03-01" "$(purge "${TSHDIR}" 1)"
	assert_eq "" "$(find "${TSHDIR}/attic/2019/03/01" -type f)"
fi

if testcase "attic already present"; then
	mkdir -p "${TSHDIR}/2019-03-01/rel" "${TSHDIR}/2019-03-02/rel"
	mkdir -p "${TSHDIR}/attic"
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF

	assert_eq "${TSHDIR}/2019-03-01" "$(purge "${TSHDIR}" 1)"

	[ -d "${TSHDIR}/2019-03-02" ] ||
		fail "expected 2019-03-02 to be left"
	[ -d "${TSHDIR}/attic/2019/03/01" ] ||
		fail "expected 2019-03-01 to be moved"
fi
