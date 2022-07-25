# ports_config_load
#
# Handle ports specific configuration.
ports_config_load() {
	# Sanitize the inherited environment.
	unset MAKEFLAGS PKG_PATH
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
	dpb)
		if [ "$_exit" = 0 ]; then
			diff -U0 -L packages.orig -L packages \
				"${_tmpdir}/"packages{.orig,} 2>/dev/null || :
		else
			tail "$_log"
		fi
		;;
	distrib)
		cat "$_log"
		;;
	*)
		tail "$_log"
		;;
	esac
}

# ports_report_skip -b build-dir -n step-name -l step-log -t tmp-dir
#
# Exits zero if the given step should not be included in the report.
ports_report_skip() {
	local _name

	while [ $# -gt 0 ]; do
		case "$1" in
		-b)	shift;;
		-l)	shift;;
		-n)	shift; _name="$1";;
		-t)	shift;;
		*)	break;;
		esac
		shift
	done
	: "${_name:?}"

	case "$_name" in
	cvs)	return 1;;
	dpb)	return 1;;
	*)	return 0;;
	esac
}

# ports_steps
#
# Get the step names in order of execution.
ports_steps() {
	xargs printf '%s\n' <<-EOF
	env
	cvs
	clean
	proot
	patch
	dpb
	distrib
	revert
	end
	EOF
}
