portable no

BUILDDIR="$TSHDIR"; export BUILDDIR
EXECDIR="$TSHDIR"

# Ensure the step time is only stamped when the same step is started.
if testcase "step time"; then
	_steps="$(step_path "$TSHDIR")"

	cat <<-EOF >"${EXECDIR}/robsd-env.sh"
	"$ROBSDSTEP" -W -f "$_steps" -i 1 -- time=1666666666
	EOF

	robsd_config - <<-EOF
	robsddir "$TSHDIR"
	EOF

	(setmode "robsd" && config_load </dev/null && build_init "$TSHDIR" &&
	 robsd -b "$TSHDIR" -s 1) >"$TMP1" 2>&1 || :

	assert_file - "$TMP1" <<-EOF
	robsd-test: step env
	EOF

	step_eval -n env "$_steps"
	assert_eq "1666666666" "$(step_value time)"
fi
