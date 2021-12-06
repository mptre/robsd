# regress_config_load
#
# Parse the configured regression tests and handle any associated flags.
regress_config_load() {
	local _f
	local _flags
	local _t
	local _tests=""

	# Prevent tests from picking up compiler flags in bsd.sys.mk.
	unset DESTDIR
	# Not suited for parallelism.
	unset MAKEFLAGS

	for _t in ${TESTS:-}; do
		_flags="${_t##*:}"
		_t="${_t%:*}"

		[ "$_flags" = "$_t" ] && _flags=""

		# shellcheck disable=SC2001
		for _f in $(echo "$_flags" | sed -e 's/\(.\)/\1 /g'); do
			case "$_f" in
			R)	REGRESSROOT="${REGRESSROOT}${REGRESSROOT:+ }${_t}";;
			S)	SKIPIGNORE="${SKIPIGNORE}${SKIPIGNORE:+ }${_t}";;
			*)	fatal "unknown regress test flag '${_f}'";;
			esac
		done

		_tests="${_tests}${_tests:+ }${_t}"
	done
	TESTS="$_tests"
}

# regress_failed step-log
#
# Exits zero if the given regress step log indicate failure.
regress_failed() {
	local _log

	_log="$1"; : "${_log:?}"
	grep -q '^FAILED$' "$_log"
}

# regress_report_log -e step-exit -n step-name -l step-log -t tmp-dir
#
# Get an excerpt of the given step log.
regress_report_log() {
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

	regress_tests 'FAILED|SKIPPED|: process group exited ' "$_log" |
	tee "${_tmpdir}/regress"
	[ -s "${_tmpdir}/regress" ] || tail "$_log"
	return 0
}

# regress_report_skip -n step-name -l step-log
#
# Exits zero if the given step should not be included in the report.
regress_report_skip() {
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

	# Do not skip if one or many tests where skipped.
	if ! regress_skip "$_name" &&
	   ! regress_tests SKIPPED "$_log" | cmp -s - /dev/null; then
		return 1
	fi
	return 0
}

# regress_root test
#
# Exits zero if the given regress test must be executed as root.
regress_root() {
	local _test

	_test="$1"; : "${_test:?}"
	echo "$REGRESSROOT" | grep -q "\<${_test}\>"
}

# regress_skip test
#
# Exits zero if the given regress test should be omitted from the report even if
# some tests where skipped.
regress_skip() {
	local _test

	_test="$1"; : "${_test:?}"
	echo "$SKIPIGNORE" | grep -q "\<${_test}\>"
}

# regress_step_after -b build-dir -e step-exit -n step-name
#
# After step hook, exits 0 if we can continue.
regress_step_after() {
	local _exit
	local _name

	while [ $# -gt 0 ]; do
		case "$1" in
		-b)	shift;;
		-e)	shift; _exit="$1";;
		-n)	shift; _name="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_exit:?}"
	: "${_name:?}"

	# Ignore regress test errors.
	case "$TESTS" in
	*${_name}*)	return 0;;
	*)		return "$_exit";;
	esac
}

# regress_steps
#
# Get the step names in execution order.
regress_steps() {
	xargs printf '%s\n' <<-EOF
	env
	${TESTS}
	end
	EOF
}

# regress_tests outcome-pattern step-log
#
# Extract all regress tests from the log matching the given outcome pattern.
regress_tests() {
	local _outcome
	local _log

	_outcome="$1"; : "${_outcome:?}"
	_log="$2"; : "${_log:?}"

	awk '
	/^$/ { buf = ""; next }
	{ buf = buf "\n" $0 }
	/^'"$_outcome"'/ { printf("%s\n", buf); buf = "" }
	' "$_log" | tail -n +2
}
