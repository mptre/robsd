# cross_steps
#
# Get the step names in order of execution.
cross_steps() {
	cat <<-EOF
	env
	dirs
	tools
	distrib
	dmesg
	end
	EOF
}
