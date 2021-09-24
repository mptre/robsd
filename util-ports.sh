# ports_config_load
#
# Handle ports specific configuration.
ports_config_load() {
	# Do not inherit anything.
	unset PKG_PATH
}

# ports_path [-C]
#
# Get the ports bin directory, relative to the chroot or not.
ports_path() {
	local _chroot="$CHROOT"

	while [ $# -gt 0 ]; do
		case "$1" in
		-C)	_chroot="";;
		*)	break;;
		esac
		shift
	done

	echo "${_chroot}${PORTSDIR}/infrastructure/bin"
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
	end
	EOF
}
