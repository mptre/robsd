# regress_config_load
#
# Handle regress specific configuration.
regress_config_load() {
	# Sanitize the inherited environment.
	unset MAKEFLAGS
}

# regress_duration_total -s steps
#
# Calculate the total duration. Since robsd-regress runs steps in parallel, the
# accumulated step duration cannot be used. Instead, favor the wall clock delta
# between the last and first step.
regress_duration_total() {
	local _t0=0
	local _t1=0
	local _steps

	while [ $# -gt 0 ]; do
		case "$1" in
		-s)	shift; _steps="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_steps:?}"

	if step_eval 1 "$_steps" 2>/dev/null; then
		_t0="$(step_value time)"
	fi
	if step_eval -1 "$_steps" 2>/dev/null; then
		_t1="$(step_value time)"
	fi
	echo "$((_t1 - _t0))"
}

# regress_failed step-log
#
# Exits zero if the given regress step log indicates failure.
regress_failed() {
	local _log

	_log="$1"; : "${_log:?}"
	regress_log -FPn "$_log"
}

# regress_log [robsd-regress-log-argument ...]
#
# Exec wrapper for robsd-regress-log.
regress_log() {
	"${ROBSDREGRESSLOG:-${EXECDIR}/robsd-regress-log}" "$@"
}

# regress_makefile dir
#
# Get the name of the makefile present in the given directory if it deviates
# from the default one.
regress_makefile() {
	local _dir

	_dir="$1"; : "${_dir:?}"
	if [ -e "${_dir}/Makefile.bsd-wrapper" ]; then
		echo "Makefile.bsd-wrapper"
	fi
}

# regress_root test
#
# Exits zero if the given regress test must be executed as root.
regress_root() {
	local _test

	_test="$1"; : "${_test:?}"
	config_value "regress-${_test}-root" >/dev/null 2>&1
}

# regress_step_after -b build-dir -e step-exit -n step-name
#
# After step hook, exits 0 if we can continue.
regress_step_after() {
	local _exit
	local _name

	while [ $# -gt 0 ]; do
		case "$1" in
		-b)	shift;;
		-e)	shift; _exit="$1";;
		-n)	shift; _name="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_exit:?}"
	: "${_name:?}"

	# Ignore regress test errors.
	if config_value regress | xargs printf '%s\n' |
	   grep -q "^${_name}$"; then
		return 0
	fi
	return "$_exit"
}
