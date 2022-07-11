# cross_report_subject
#
# Get report subject prefix, including the target.
cross_report_subject() {
	printf '%s.%s: ' "$(machine)" "$(config_value target)"
}

# cross_steps
#
# # Get the step names in order of execution.
cross_steps() {
	cat <<-EOF
	env
	dirs
	tools
	distrib
	end
	EOF
}
