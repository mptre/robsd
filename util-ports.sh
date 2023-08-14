# ports_config_load
#
# Handle ports specific configuration.
ports_config_load() {
	# Sanitize the inherited environment.
	unset MAKEFLAGS PKG_PATH
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
	dmesg
	end
	EOF
}
