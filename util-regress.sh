# regress_config_load
#
# Handle regress specific configuration.
regress_config_load() {
	# Sanitize the inherited environment.
	unset MAKEFLAGS
}

# regress_failed step-log
#
# Exits zero if the given regress step log indicate failure.
regress_failed() {
	local _log

	_log="$1"; : "${_log:?}"
	regress_log -Fn "$_log"
}

# regress_log [robsd-regress-log-argument ...]
#
# Exec wrapper for robsd-regress-log.
regress_log() {
	${EXEC:-} "${ROBSDREGRESSLOG:-${EXECDIR}/robsd-regress-log}" "$@"
}

# regress_report_log -e step-exit -n step-name -l step-log -t tmp-dir
#
# Get an excerpt of the given step log.
regress_report_log() {
	local _name
	local _log
	local _quiet=""

	while [ $# -gt 0 ]; do
		case "$1" in
		-e)	shift;;
		-n)	shift; _name="$1";;
		-l)	shift; _log="$1";;
		-t)	shift;;
		*)	break;;
		esac
		shift
	done
	: "${_log:?}"
	: "${_name:?}"

	regress_quiet "$_name" || _quiet="yes"
	regress_log -EF ${_quiet:+-S} "$_log" || tail "$_log"
}

# regress_report_skip -b build-dir -n step-name -l step-log -t tmp-dir
#
# Exits zero if the given step should not be included in the report.
regress_report_skip() {
	local _log
	local _name
	local _tmpdir

	while [ $# -gt 0 ]; do
		case "$1" in
		-b)	shift;;
		-l)	shift; _log="$1";;
		-n)	shift; _name="$1";;
		-t)	shift; _tmpdir="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_log:?}"
	: "${_name:?}"

	# Do not skip if one or many tests where skipped.
	if ! regress_quiet "$_name" && regress_log -Sn "$_log"; then
		return 1
	fi
	return 0
}

# regress_report_status -s steps
#
# Get the report status subject.
regress_report_status() {
	local _n
	local _steps

	while [ $# -gt 0 ]; do
		case "$1" in
		-s)	shift; _steps="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_steps:?}"

	_n="$(step_failures "$_steps")"
	if [ "$_n" -gt 1 ]; then
		echo "${_n} failures"
	elif [ "$_n" -gt 0 ]; then
		echo "${_n} failure"
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

# regress_quiet test
#
# Exits zero if the given regress test should be omitted from the report even if
# some tests where skipped.
regress_quiet() {
	local _test

	_test="$1"; : "${_test:?}"
	config_value "regress-${_test}-quiet" >/dev/null 2>&1
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

# regress_steps
#
# Get the step names in order of execution.
regress_steps() {
	xargs printf '%s\n' <<-EOF
	env
	pkg-add
	cvs
	patch
	obj
	mount
	$(config_value regress)
	umount
	revert
	pkg-del
	dmesg
	end
	EOF
}
