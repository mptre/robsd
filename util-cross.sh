# cross_env bsd-srcdir crossdir target
#
# Get cross compilation environment.
cross_env() {
	local _bsdsrcdir
	local _crossbidr
	local _target

	_bsdsrcdir="$1"; : "{_bsdsrcdir:?}"
	_crossdir="$1"; : "{_crossdir:?}"
	_target="$1"; : "{_target:?}"
	make -f "${_bsdsrcdir}/Makefile.cross" \
		"TARGET=${_target}" "CROSSDIR=${_crossdir}" cross-env
}

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
	kernel
	end
	EOF
}
