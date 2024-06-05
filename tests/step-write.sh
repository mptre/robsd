portable no

BUILDDIR="${TSHDIR}"; export BUILDDIR

if testcase "basic"; then
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	: >"${TMP1}"

	step_write -t -s 2 -n cvs -e 0 -d 2 "${TMP1}"

	step_eval -n cvs "${TMP1}"
	assert_eq "2" "$(step_value duration)" "duration"
	assert_eq "cvs" "$(step_value name)" "name"
	assert_eq "2" "$(step_value step)" "step"
	assert_eq "0" "$(step_value exit)" "exit"
	assert_eq "0" "$(step_value skip)" "skip"
fi

if testcase "skip"; then
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	: >"${TMP1}"

	step_write -S -t -s 2 -n cvs -e 0 -d 0 "${TMP1}"

	step_eval -n cvs "${TMP1}"
	assert_eq "1" "$(step_value skip)" "skip"
fi
