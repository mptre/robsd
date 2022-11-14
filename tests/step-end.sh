BUILDDIR="$TSHDIR"; export BUILDDIR

if testcase "basic"; then
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF

	step_end -d 2 -n cvs -s 2 "$TMP1"

	step_eval -n cvs "$TMP1"
	assert_eq "2" "$(step_value step)" "step"
	assert_eq "cvs" "$(step_value name)" "name"
	assert_eq "0" "$(step_value exit)" "exit"
	assert_eq "2" "$(step_value duration)" "duration"
fi

if testcase "already present"; then
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	step_serialize -s 2 -n cvs >"$TMP1"

	step_end -d 2 -n cvs -s 2 "$TMP1"

	step_eval -n cvs "$TMP1"
	assert_eq "2" "$(step_value duration)" "duration"
	assert_eq "1" "$(wc -l "$TMP1" | awk '{print $1}')"
fi

if testcase "skip"; then
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF

	step_end -S -n cvs -s 10 "$TMP1"
	step_end -d 1 -n env -s 1 "$TMP1"
	step_end -d 3 -n patch -s 2 "$TMP1"

	sed 's/ name=.*//' "$TMP1" >"${TSHDIR}/tmp2"
	assert_file - "${TSHDIR}/tmp2" <<-EOF
	step="1"
	step="2"
	step="10"
	EOF
fi
