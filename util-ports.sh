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
