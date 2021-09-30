# ports_config_load
#
# Handle ports specific configuration.
ports_config_load() {
	# Parallelism is dictated by MAKE_JOBS.
	unset MAKEFLAGS
	# Do not inherit anything.
	unset PKG_PATH
}

# port_make port target
#
# Execute the given make target for the port.
port_make() {
	local _path
	local _port
	local _target

	_port="$1"; : "${_port:?}"
	_target="$2"; : "${_target:?}"

	_path="$(ports_path "$_port")"
	make -C "$_path" "PORTSDIR=${CHROOT}${PORTSDIR}" "$_target"
}

# ports_path [-C] port
#
# Get port path, relative to the chroot or not.
ports_path() {
	local _chroot="$CHROOT"
	local _port

	while [ $# -gt 0 ]; do
		case "$1" in
		-C)	_chroot="";;
		*)	break;;
		esac
		shift
	done
	_port="$1"; : "${_port:?}"

	if [ -e "${_chroot}${PORTSDIR}/${_port}" ]; then
		echo "${_chroot}${PORTSDIR}/${_port}" 
	elif [ -e  "${_chroot}${PORTSDIR}/mystuff/${_port}" ]; then
		echo "${_chroot}${PORTSDIR}/mystuff/${_port}"
	else
		echo "ports_path: ${_port}: no such directory" 1>&2
		return 1
	fi
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

	printf '\n'
	case "$_name" in
	cvs)
		cat "$_log"
		;;
	*)
		if [ "$_exit" -eq 0 ]; then
			awk '/PLIST\.orig/,EOF' "$_log" | tee "${_tmpdir}/ports"
			[ -s "${_tmpdir}/ports" ] && return 0
		fi
		tail "$_log"
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
	env|proot|outdated|end)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

# ports_steps
#
# Get the step names in execution order.
ports_steps() {
	# The outdated.log will eventually be populated by the outdated step.
	xargs printf '%s\n' <<-EOF
	env
	cvs
	proot
	outdated
	$(cat "${BUILDDIR}/outdated.log" 2>/dev/null)
	end
	EOF
}
