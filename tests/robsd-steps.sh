ROBSDSTEPS="${EXECDIR}/robsd-steps"

if testcase "basic"; then
	config_stub
	sh "$ROBSDSTEPS" >/dev/null
fi
