BUILDDIR="$TSHDIR"; export BUILDDIR
EXECDIR="$TSHDIR"

# Ensure the step time is only stamped when the same step is started.
if testcase "step time"; then
	_steps="$(step_path "$TSHDIR")"

	cat <<-EOF >"${EXECDIR}/robsd-env.sh"
	sed -in '/name="env"/s/time="[^"]*"/time="1666666666"/' "$_steps"
	EOF

	robsd_config - <<-EOF
	robsddir "$TSHDIR"
	EOF
	if (setmode "robsd" && config_load </dev/null && robsd 1) >"$TMP1" 2>&1; then
		fail - "expected exit non-zero" <"$TMP1"
	fi
	assert_file - "$TMP1" <<-EOF
	robsd-test: step env
	EOF

	step_eval -n env "$_steps"
	assert_eq "1666666666" "$(step_value time)"
fi
