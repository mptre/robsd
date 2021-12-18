# ports_config_load
#
# Handle ports specific configuration.
ports_config_load() {
	# Sanitize the inherited environment.
	unset MAKEFLAGS PKG_PATH
}

# ports_duration_total -s steps
#
# Get the total duration.
ports_duration_total() {
	local _d
	local _i=1
	local _name
	local _steps
	local _tot=0

	while [ $# -gt 0 ]; do
		case "$1" in
		-s)	shift; _steps="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_steps:?}"

	while step_eval "$_i" "$_steps" 2>/dev/null; do
		_i=$((_i + 1))

		step_skip && continue

		_name="$(step_value name)"

		# Do not include the previous accumulated build duration.
		# Could be present if the report is re-generated.
		[ "$_name" = "end" ] && continue

		# Ports are already covered by the dpb duration.
		case "$PORTS" in
		*${_name}*)	continue;;
		*)		;;
		esac

		_d="$(step_value duration)"
		_tot=$((_tot + _d))
	done

	echo "$_tot"
}

# ports_report_log -e step-exit -n step-name -l step-log -t tmp-dir
#
# Get an excerpt of the given step log.
ports_report_log() {
	local _exit
	local _name
	local _log
	local _tmpdir

	while [ $# -gt 0 ]; do
		case "$1" in
		-e)	shift; _exit="$1";;
		-n)	shift; _name="$1";;
		-l)	shift; _log="$1";;
		-t)	shift; _tmpdir="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_exit:?}"
	: "${_name:?}"
	: "${_log:?}"
	: "${_tmpdir:?}"

	case "$_name" in
	cvs)
		cat <<-EOF | while read -r _f
		${_tmpdir}/cvs-ports-up.log
		${_tmpdir}/cvs-ports-ci.log
		EOF
		do
			[ -s "$_f" ] || continue
			cat "$_f"; echo
		done
		;;
	distrib)
		cat "$_log"
		;;
	*)
		[ "$_exit" -eq 0 ] || tail "$_log"
		;;
	esac
}

# ports_report_skip -n step-name -l step-log
#
# Exits zero if the given step should not be included in the report.
ports_report_skip() {
	local _log
	local _name

	while [ $# -gt 0 ]; do
		case "$1" in
		-l)	shift; _log="$1";;
		-n)	shift; _name="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_log:?}"
	: "${_name:?}"

	case "$_name" in
	env|proot|dpb|distrib|end)
		return 0
		;;
	cvs)
		return 1
		;;
	*)
		! echo "$PORTS" | grep -q "\<${_name}\>"
		;;
	esac
}

# ports_report_status -s steps
#
# Get the report status subject.
ports_report_status() {
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
	[ "$_n" -gt 0 ] || return 0

	if [ "$_n" -gt 1 ] &&
	   step_eval -n dpb "$_steps" 2>/dev/null &&
	   [ "$(step_value exit)" -ne 0 ]; then
		_n=$((_n - 1))
	fi

	if [ "$_n" -gt 1 ]; then
		echo "${_n} failures"
	else
		echo "${_n} failure"
	fi
}

# ports_step_after -b build-dir -e step-exit -n step-name
#
# After step hook, exits 0 if we can continue.
ports_step_after() {
	local _exit

	while [ $# -gt 0 ]; do
		case "$1" in
		-b)	shift;;
		-e)	shift; _exit="$1";;
		-n)	shift;;
		*)	break;;
		esac
		shift
	done
	: "${_exit:?}"

	return "$_exit"
}

# ports_step_skip -n step-name
#
# Exits zero if the step has been skipped.
ports_step_skip() {
	local _name

	while [ $# -gt 0 ]; do
		case "$1" in
		-n)	shift; _name="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_name:?}"

	# Ports are already covered the dpb step.
	echo "$PORTS" | grep -q "\<${_name}\>"
}

# ports_steps
#
# Get the step names in execution order.
ports_steps() {
	xargs printf '%s\n' <<-EOF
	env
	cvs
	proot
	${PORTS}
	dpb
	distrib
	end
	EOF
}
