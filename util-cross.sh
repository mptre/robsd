# cross_report_subject -b build-dir
#
# Get report subject prefix, including the target.
cross_report_subject() {
	local _builddir

	while [ $# -gt 0 ]; do
		case "$1" in
		-b)	shift; _builddir="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_builddir:?}"

	printf '%s.%s: ' "$(machine)" "$(<"${_builddir}/target")"
}

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
