# ports_begin -n step -s steps-file
#
# Exits 0 if the given step can be executed.
ports_begin() {
	local _name
	local _steps

	while [ $# -gt 0 ]; do
		case "$1" in
		-n)	shift; _name="$1";;
		-s)	shift; _steps="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_name:?}"
	: "${_steps:?}"

	if [ "$_name" = "distrib" ] &&
	   [ "$(step_failures "$_steps")" -gt 0 ]; then
		return 1
	fi
	return 0
}

# ports_config_load
#
# Handle ports specific configuration.
ports_config_load() {
	# Parallelism is dictated by MAKE_JOBS.
	unset MAKEFLAGS
	# Do not inherit anything.
	unset PKG_PATH
}

# ports_parallel port
#
# Exits zero if the given port can build in parallel.
ports_parallel() {
	local _port

	_port="$1"; : "${_port:?}"
	! echo "$NOPARALLEL" | grep -q "\<${_port}\>"
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
	env|proot|outdated|distrib|end)
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

# ports_step_after -b build-dir -e step-exit -n step-name
#
# After step hook, exits 0 if we can continue.
ports_step_after() {
	local _builddir
	local _exit
	local _n
	local _name
	local _outdated
	local _s
	local _steps

	while [ $# -gt 0 ]; do
		case "$1" in
		-b)	shift; _builddir="$1";;
		-e)	shift; _exit="$1";;
		-n)	shift; _name="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_builddir:?}"
	: "${_exit:?}"
	: "${_name:?}"

	_outdated="${_builddir}/tmp/outdated"
	_steps="${_builddir}/steps"

	# After the outdated step, adjust step ids for any following skipped
	# steps since the number of steps has most likely increased after
	# finding all outdated ports.
	if [ "$_name" = "outdated" ]; then
		_n="$(wc -l "$_outdated" | awk '{print $1}')"
		step_eval -n "outdated" "${_builddir}/steps"
		_s="$(step_value step)"; _s=$((_s + 1))
		cp "${_builddir}/steps" "${_builddir}/tmp/steps"
		while step_eval "$_s" "${_builddir}/tmp/steps" 2>/dev/null; do
			step_skip || break

			step_end -S -n "$(step_value name)" -s "$((_s + _n))" \
				"$_steps"
			_s=$((_s + 1))
		done
		rm "${_builddir}/tmp/steps"
	fi

	# Ignore ports build errors.
	case "$(cat "$_outdated" 2>/dev/null)" in
	*${_name}*)	return 0;;
	*)		return "$_exit";;
	esac
}

# ports_steps
#
# Get the step names in execution order.
ports_steps() {
	local _outdated="${BUILDDIR}/tmp/outdated"

	# The outdated file will eventually be populated by the outdated step.
	xargs printf '%s\n' <<-EOF
	env
	cvs
	proot
	outdated
	$( ([ -s "$_outdated" ] && cat "$_outdated" ) || :)
	distrib
	end
	EOF
}
