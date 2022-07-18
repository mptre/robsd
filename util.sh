# abs number
#
# Get the absolute value of the given number.
abs() {
	local _n

	_n="$1"; : "{$_n:?}"

	: "${_n:?}"

	if [ "$_n" -lt 0 ]; then
		echo "$((- _n))"
	else
		echo "$_n"
	fi
}

# build_date
#
# Get the release build start date.
build_date() {
	step_eval 1 "${BUILDDIR}/steps"
	step_value time
}

# build_id robsd-dir
#
# Generate a new build directory path.
build_id() {
	local _c
	local _d

	_d="$(date '+%Y-%m-%d')"
	_c="$(find "$1" -type d -name "${_d}*" | wc -l)"
	printf '%s.%d\n' "$_d" "$((_c + 1))"
}

# build_init build-dir
#
# Initialize the given build directory.
build_init() {
	local _builddir

	_builddir="$1"; : "${_builddir:?}"

	[ -d "$_builddir" ] || mkdir "$_builddir"
	[ -d "${_builddir}/tmp" ] || mkdir "${_builddir}/tmp"
	[ -e "${_builddir}/robsd.log" ] || : >"${_builddir}/robsd.log"
	[ -e "${_builddir}/steps" ] || : >"${_builddir}/steps"
	return 0
}

# check_perf
#
# Sanity check performance parameters. Some architectures does however not
# support performance tuning.
check_perf() {
	local _perf

	case "$(sysctl -n hw.perfpolicy 2>/dev/null)" in
	auto|high)	return 0;;
	*)		;;
	esac

	_perf="$(sysctl -n hw.setperf 2>/dev/null)"
	if [ -z "$_perf" ] || [ "$_perf" -eq 100 ]; then
		return 0
	fi

	info "non-optimal performance detected, check hw.perfpolicy and hw.setperf"
	return 1
}

# cleandir dir ...
#
# Remove all entries in the given directory without removing the actual
# directory.
cleandir() {
	local _d

	for _d; do
                find "$_d" -mindepth 1 -maxdepth 1 -print0 | xargs -0r rm -r
	done
}

# config_load [robsd-config-argument ...]
#
# Load and validate the configuration.
# shellcheck disable=SC2120
config_load() {
	local _err=0
	local _tmp

	: "${BUILDDIR:=}"; export BUILDDIR
	: "${DETACH:=1}"
	: "${EXECDIR:=/usr/local/libexec/robsd}"; export EXECDIR
	PATH="${PATH}:/usr/X11R6/bin"; export PATH
	: "${ROBSDCONFIG:=${EXECDIR}/robsd-config}"
	: "${ROBSDHOOK:=${EXECDIR}/robsd-hook}"
	: "${ROBSDSTAT:=${EXECDIR}/robsd-stat}"

	_tmp="$(mktemp -t robsd.XXXXXX)"
	{
		cat
		echo "EXECDIR=\${execdir}"
	} | "$ROBSDCONFIG" -m "$_MODE" ${ROBSDCONF:+"-f${ROBSDCONF}"} "$@" - \
		>"$_tmp" || _err="$?"
	[ "$_err" -eq 0 ] && eval "$(<"$_tmp")"
	rm "$_tmp"
	[ "$_err" -eq 0 ] || return "$_err"

	case "$_MODE" in
	robsd|robsd-cross)
		MAKEFLAGS="-j$(sysctl -n hw.ncpuonline)"; export MAKEFLAGS
		;;
	robsd-ports)
		ports_config_load
		;;
	robsd-regress)
		regress_config_load
		;;
	*)
		return 1
		;;
	esac
}

# config_value variable
#
# Get the corresponding value for the given configuration variable.
config_value()
{
	local _var

	_var="$1"; : "${_var:?}"

	echo "echo \${${_var}}" | config_load
}

# cvs_field field log-line
#
# Extract the given field from a cvs log line.
cvs_field() {
	local _field
	local _line

	_field="$1"; : "${_field:?}"
	_line="$2"; : "${_line:?}"

	echo "$_line" | grep -q -F "$_field" || return 1

	_line="${_line##*"${_field}": }"; _line="${_line%%;*}"
	echo "$_line"
}

# cvs_date -s steps
#
# Get the date of the CVS update invocation expressed as a Unix timestamp for
# the given release.
cvs_date() {
	local _log
	local _steps

	while [ $# -gt 0 ]; do
		case "$1" in
		-s)	shift; _steps="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_steps:?}"

	step_eval -n cvs "$_steps"
	step_skip && return 1

	# Try to find the date of the last revision in the log, i.e. the first
	# entry written by cvs_log(). If nothing was updated, use the step
	# execution date of the cvs step as a fallback.
	_log="$(step_value log 2>/dev/null)"
	_date="$(grep -m 1 '^Date:' "$_log" | sed -e 's/^[^:]*: *//')"
	if [ -n "$_date" ]; then
		date -j -f '%Y/%m/%d %H:%M:%S' '+%s' "$_date"
	else
		step_value time
	fi
}

# cvs_log -r robsd-dir -t tmp-dir  -c cvs-dir -h cvs-host -u cvs-user
#
# Generate a descending log of all commits since the last release build for the
# given repository. Individual revisions are group by commit id and sorted by
# date.
cvs_log() {
	local _date=""
	local _id
	local _indent="  "
	local _line
	local _log
	local _message=0
	local _path
	local _prev
	local _repo
	local _user

	while [ $# -gt 0 ]; do
		case "$1" in
		-r)	shift; _robsddir="$1";;
		-t)	shift; _tmp="${1}/cvs";;
		-c)	shift; _repo="$1";;
		-h)	shift; _host="$1";;
		-u)	shift; _user="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_robsddir:?}"
	: "${_tmp:?}"
	: "${_repo:?}"
	: "${_host:?}"
	: "${_user:?}"

	[ -d "$_tmp" ] && rm -r "$_tmp"
	mkdir -p "$_tmp"

	# Use the date from latest revision from the previous release.
	for _prev in $(prev_release -r "$_robsddir" 0); do
		_date="$(cvs_date -s "${_prev}/steps")" && break
	done
	if [ -z "$_date" ]; then
		echo "cvs_log: previous date not found" 1>&2
		return 0
	fi
	_date="$(date -r "$_date" '+%F %T')"

	grep '^[MPU]\>' |
	cut -d ' ' -f 2 |
	unpriv "$_user" "cd ${_repo} && xargs cvs -q -d ${_host} log -N -l -d '>${_date}'" |
	tee "${_tmp}/cvs.log" |
	while read -r _line; do
		case "$_line" in
		Working\ file:*)
			_path="${_line#*: }"
			;;
		date:*)
			_date="$(cvs_field date "$_line")"
			_id="$(cvs_field commitid "$_line")" || continue
			if ! [ -d "${_tmp}/${_id}" ]; then
				mkdir "${_tmp}/${_id}"
				{
					echo "commit ${_id}"
					echo "Author: $(cvs_field author "$_line")"
					echo "Date: ${_date}"
					echo
				} >"${_tmp}/${_id}/message"
				# Replace trailing newline with space,
				# simplifies sorting below.
				echo -n "${_date} " >"${_tmp}/${_id}/date"
				_message=1
			fi
			echo "${_indent}${_path}" >>"${_tmp}/${_id}/files"
			;;
		-[-]*|=[=]*)
			_message=0
			;;
		*)
			if [ "$_message" -eq 1 ]; then
				echo "${_indent}${_line}" >>"${_tmp}/${_id}/message"
			fi
			;;
		esac
	done

	# Sort each commit using the date file.
	find "$_tmp" \( -type f -name date \) \
		-exec sh -c 'cat $1; echo $1' _ {} \; |
	sort -nr |
	sed -e 's/.* //' -e 's,/date,,' |
	while read -r _path; do
		cat "${_path}/message"
		echo
		cat "${_path}/files"
		echo
	done |
	sed -e 's/^[[:space:]]*$//'
}

# diff_apply -d root-dir -t tmp-dir -u user diff
#
# Apply the given diff, operating as user.
diff_apply() (
	local _diff
	local _dir
	local _err=0
	local _strip
	local _tmp
	local _user
	local _root

	while [ $# -gt 0 ]; do
		case "$1" in
		-d)	shift; _dir="$1";;
		-t)	shift; _tmp="${1}/diff-apply";;
		-u)	shift; _user="$1";;
		*)	break;;
		esac
		shift
	done
	_diff="$1"
	: "${_dir:?}"
	: "${_tmp:?}"
	: "${_user:?}"
	: "${_diff:?}"

	_root="$(diff_root -d "$_dir" "$_diff")"
	cd "$_root"

	# Try to revert the diff if dry run fails.
	if ! unpriv "$_user" "exec patch -C -Efs" <"$_diff" >/dev/null; then
		unpriv "$_user" "exec patch -R -Efs" <"$_diff"
	fi
	# Use the strip argument in order to cope with files in newly created
	# directories since they would otherwise end up in the current working
	# directory. However, we could operate on a Git diff in which prefixes
	# must be stripped.
	for _strip in 0 1; do
		if unpriv "$_user" "exec patch -Efs -p ${_strip}" \
		   <"$_diff" >"$_tmp" 2>&1; then
			break
		fi
	done
	[ -s "$_tmp" ] && _err=1
	cat "$_tmp"
	rm -f "$_tmp"
	return "$_err"
)

# diff_clean dir
#
# Remove leftovers from cvs and patch in dir.
diff_clean() {
	find "$1" -type f \( \
		-name '*.orig' -o -name '*.rej' -o -name '.#*' \) -print0 |
	xargs -0r rm
}

# diff_copy -d directory dst [src ...]
#
# Copy the given diff(s) located at src to dst. The directory argument is the
# fallback argument to diff_root.
diff_copy() {
	local _base
	local _dst
	local _i=1
	local _r
	local _root
	local _src

	while [ $# -gt 0 ]; do
		case "$1" in
		-d)	shift; _root="$1";;
		*)	break;;
		esac
		shift
	done
	_base="$1"; shift
	: "${_root:?}"
	: "${_base:?}"

	for _src; do
		_dst="${_base}.${_i}"

		_r="$(diff_root -d "$_root" "$_src")"
		info "using diff ${_src} rooted in ${_r}"

		{ printf '# %s\n\n' "$_src"; cat "$_src"; } >"$_dst"
		chmod 644 "$_dst"

		_i=$((_i + 1))
	done
}

# diff_list build-dir prefix
#
# List all diff in the given dir matching prefix.
diff_list() {
	local _builddir
	local _prefix

	_builddir="$1" ; : "${_builddir:?}"
	_prefix="$2" ; : "${_prefix:?}"

	find "$_builddir" -maxdepth 1 -type f -name "${_prefix}.*" | sort
}

# diff_revert -d dir -t tmp-dir -u user diff
#
# Revert the given diff, operating as user.
diff_revert() (
	local _diff
	local _dir
	local _p
	local _revert=""
	local _root
	local _user

	while [ $# -gt 0 ]; do
		case "$1" in
		-d)	shift; _dir="$1";;
		-t)	shift; _revert="${1}/revert";;
		-u)	shift; _user="$1";;
		*)	break;;
		esac
		shift
	done
	_diff="$1"
	: "${_dir:?}"
	: "${_revert:?}"
	: "${_user:?}"
	: "${_diff:?}"

	_root="$(diff_root -d "$_dir" "$_diff")"
	cd "$_root"

	if unpriv "$_user" "exec patch -CR -Efs" <"$_diff" >/dev/null 2>&1; then
		info "reverting diff ${_diff}"
		unpriv "$_user" "exec patch -R -Ef" <"$_diff" >"$_revert"
	else
		info "diff already reverted ${_diff}"
	fi
	if [ -e "$_revert" ]; then
		diff_clean "$_dir"

		# Remove empty directories.
		sed -n -e 's/^Removing \([^[:space:]]*\) (empty .*/\1/p' "$_revert" |
		xargs -r -L 1 dirname |
		sort |
		uniq |
		while read -r _p; do
			info "removing empty directory ${_root}/${_p}"
			rmdir "$_p"
		done
	fi
	rm -f "$_revert"
)

# diff_root -d directory diff
#
# Find the root directory for the given diff. Otherwise, use the given directory
# as a fallback.
diff_root() {
	local _err=1
	local _file
	local _p
	local _path
	local _root

	while [ $# -gt 0 ]; do
		case "$1" in
		-d)	shift; _root="$1";;
		*)	break
		esac
		shift
	done
	: "${_root:?}"

	grep -e '^Index:' -e '^RCS file:' "$1" |
	awk '{print $NF}' |
	sed -e 's/,v$//' |
	head -2 |
	xargs |
	while read -r _file _path; do
		_p="${_path%/"${_file}"}"
		while [ -n "$_p" ]; do
			if [ -e "${_root}${_p}" ]; then
				echo "${_root}${_p}"
				_err=0
				break
			fi

			_p="$(path_strip "$_p")"
		done

		return "$_err"
	done || echo "$_root"

	return 0
}

# duration_prev -r robsd-dir step-name
#
# Get the duration for the given step from the previous successful invocation.
# Exits non-zero if no previous invocation exists or the previous one failed.
duration_prev() {
	local _duration
	local _exit
	local _prev
	local _robsddir
	local _step

	while [ $# -gt 0 ]; do
		case "$1" in
		-r)	shift; _robsddir="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_robsddir:?}"
	_step="$1"; : "${_step:?}"

	prev_release -r "$_robsddir" 0 |
	while read -r _prev; do
		step_eval -n "$_step" "${_prev}/steps" 2>/dev/null || continue
		step_skip && continue

		_exit="$(step_value exit 2>/dev/null || echo 1)"
		[ "$_exit" -eq 0 ] || continue

		_duration="$(step_value duration 2>/dev/null)" || continue
		echo "$_duration"
		return 1
	done || return 0

	return 1
}

# duration_total -s steps
#
# Calculate the accumulated build duration.
duration_total() {
	local _d
	local _i=1
	local _steps
	local _tot=0

	while [ $# -gt 0 ]; do
		case "$1" in
		-s)	shift; _steps="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_steps:?}"

	case "$_MODE" in
	robsd-ports)
		ports_duration_total -s "$_steps"
		return 0
		;;
	*)
		;;
	esac

	while step_eval "$_i" "$_steps" 2>/dev/null; do
		_i=$((_i + 1))

		step_skip && continue

		# Do not include the previous accumulated build duration.
		# Could be present if the report is re-generated.
		[ "$(step_value name)" = "end" ] && continue

		_d="$(step_value duration)"
		_tot=$((_tot + _d))
	done

	echo "$_tot"
}

# fatal message ...
#
# Print the given message to stderr and exit non-zero.
fatal() {
	info "$*" 1>&2
	exit 1
}

# format_duration duration
#
# Format the given duration to a human readable representation.
format_duration() {
	local _d

	_d="$1"; : "${_d:?}"

	date -u -r "$_d" '+%T'
}

# format_size [-s] size
#
# Format the given size into a human readable representation.
# Optionally include the sign if the size is a delta.
format_size() {
	local _abs
	local _d=1
	local _p=""
	local _sign=0
	local _size

	while [ $# -gt 0 ]; do
		case "$1" in
		-s)	_sign=1;;
		*)	break;;
		esac
		shift
	done
	_size="$1"; : "${_size:?}"

	_abs="$(abs "$_size")"
	if [ "$_abs" -ge "$((1024 * 1024))" ]; then
		_d=$((1024 * 1024))
		_p="M"
	elif [ "$_abs" -ge "1024" ]; then
		_d=1024
		_p="K"
	fi

	if [ "$_sign" -eq 1 ] && [ "$_size" -ge 0 ]; then
		echo -n '+'
	fi

	echo "${_size} ${_d} ${_p}" |
	awk '{ printf("%.01f%s", $1 / $2, $3) }'
}

# info message ...
#
# Print the given message to stdout.
info() {
	local _log="/dev/null"

	if [ "${DETACH:-0}" -le 1 ] && [ -n "${BUILDDIR:-}" ]; then
		# Not fully detached yet, write all entries to robsd.log.
		_log="${BUILDDIR}/robsd.log"
	fi
	echo "${_PROG}: ${*}" | tee -a "$_log"
}

# lock_acquire root-dir build-dir
#
# Acquire the mutex lock.
lock_acquire() {
	local _builddir
	local _owner
	local _rootdir

	_rootdir="$1"; : "${_rootdir:?}"
	_builddir="$2"; : "${_builddir:?}"

	# We could already be owning the lock if the previous run was aborted
	# prematurely.
	_owner="$(cat "${_rootdir}/.running" 2>/dev/null || :)"
	if [ -n "$_owner" ] && [ "$_owner" != "$_builddir" ]; then
		info "${_owner}: lock already acquired"
		return 1
	fi

	echo "$_builddir" >"${_rootdir}/.running"
}

# lock_alive root-dir build-dir
#
# Exits 0 if the lock is still alive as it could be immutable which is
# signalling that robsd-kill want us dead.
lock_alive() {
	local _builddir
	local _rootdir

	_rootdir="$1"; : "${_rootdir:?}"
	_builddir="$2"; : "${_builddir:?}"
	touch "${_rootdir}/.running" 2>/dev/null || return 1
	echo "$_builddir" | cmp -s - "${_rootdir}/.running"
}

# lock_release root-dir build-dir
#
# Release the mutex lock if we did acquire it.
lock_release() {
	local _builddir
	local _rootdir

	_rootdir="$1"; : "${_rootdir:?}"
	_builddir="$2"; : "${_builddir:?}"

	if echo "$_builddir" | cmp -s - "${_rootdir}/.running"; then
		chflags nouchg "${_rootdir}/.running"
		rm -f "${_rootdir}/.running"
	else
		return 1
	fi
}

# log_id -b build-dir -n step-name -s step-id
#
# Generate the corresponding log file name for the given step.
log_id() {
	local _id
	local _name=""
	local _builddir=""
	local _step=""

	while [ $# -gt 0 ]; do
		case "$1" in
		-b)	shift; _builddir="$1";;
		-n)	shift; _name="$1";;
		-s)	shift; _step="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_name:?}"
	: "${_builddir:?}"
	: "${_step:?}"

	case "$_MODE" in
	robsd-ports|robsd-regress)
		_name="$(echo "$_name" | tr '/' '-')"
		;;
	*)
		;;
	esac

	_id="$(printf '%03d-%s.log' "$_step" "$_name")"
	_dups="$(find "$_builddir" -name "${_id}*" | wc -l)"
	if [ "$_dups" -gt 0 ]; then
		printf '%s.%d' "$_id" "$_dups"
	else
		echo "$_id"
	fi
}

# path_strip path
#
# Strip of the first component of the given path.
path_strip() {
	local _dst
	local _src

	_src="$1"; : "${_src:?}"

	_dst="${_src#/}"
	[ "${_dst#*/}" = "$_dst" ] && return 0
	echo "/${_dst#*/}"

}

# prev_release -r robsd-dir [count]
#
# Get the previous count number of release directories. Where count defaults
# to 1. If count is 0 means all previous release directories.
prev_release() {
	local _attic
	local _count
	local _robsddir

	while [ $# -gt 0 ]; do
		case "$1" in
		-r)	shift; _robsddir="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_robsddir:?}"
	_count="${1:-1}"

	# Be silent during testing.
	_attic="$(config_value keep-dir 2>/dev/null || :)"

	find "$_robsddir" -mindepth 1 -maxdepth 1 -type d |
	sort -nr |
	grep -v -e "$BUILDDIR" ${_attic:+-e ${_attic}} |
	{
		if [ "$_count" -gt 0 ]; then
			head "-${_count}"
		else
			cat
		fi
	}
}

# purge dir count
#
# Keep the latest count number of release directories in dir.
# The older ones will be moved to the keep-dir, preserving only the relevant
# files. All purged directories are written to stdout.
purge() {
	local _attic
	local _d
	local _dir
	local _dst
	local _n
	local _tim

	_dir="$1"; : "${_dir:?}"
	_n="$2"; : "${_n:?}"

	_attic="$(config_value keep-dir)"

	find "$_dir" -mindepth 1 -maxdepth 1 -type d |
	grep -v "$_attic" |
	sort -n |
	tail -r |
	tail -n "+$((_n + 1))" |
	while read -r _d; do
		[ -d "$_attic" ] || mkdir "$_attic"

		# Grab the modification time before removal of irrelevant files.
		_tim="$(stat -f '%Sm' -t '%FT%T' "$_d")"

		rm -rf "${_d}/tmp"
		find "$_d" -mindepth 1 -not \( \
			-name '*.diff.*' -o \
			-name '01-env.log' -o \
			-name 'comment' -o \
			-name 'index.txt' -o \
			-name 'report' -o \
			-name 'stat.csv' -o \
			-name 'steps' \) -delete

		# Transform: YYYY-MM-DD.X -> YYYY/MM/DD.X
		_dst="${_attic}/$(echo "${_d##*/}" | tr '-' '/')"
		# Create leading YYYY/MM directories.
		mkdir -p "${_dst%/*}"
		cp -pr "$_d" "$_dst"
		touch -d "$_tim" "$_dst"
		rm -r "$_d"
		echo "$_d"
	done
}

# report -r robsd-dir -b build-dir
#
# Create and save build report.
report() {
	local _builddir
	local _duration=""
	local _exit
	local _f
	local _i=1
	local _log
	local _n
	local _name
	local _robsddir
	local _report
	local _status
	local _steps
	local _tmp
	local _tmpdir

	while [ $# -gt 0 ]; do
		case "$1" in
		-r)	shift; _robsddir="$1";;
		-b)	shift; _builddir="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_robsddir:?}"
	: "${_builddir:?}"

	_report="${_builddir}/report"
	_steps="${_builddir}/steps"
	_tmpdir="${_builddir}/tmp"
	_tmp="${_tmpdir}/report"

	# The steps file could be empty when a build fails to start due to
	# another already running build.
	[ -s "$_steps" ] || return 1

	case "$_MODE" in
	robsd-regress)
		_status="$(regress_report_status -s "$_steps")"
		;;
	*)
		# All other robsd utilities halts if a step failed, only bother
		# checking the last non-skipped step.
		while step_eval "-${_i}" "$_steps" 2>/dev/null; do
			_i=$((_i + 1))
			step_skip && continue
			[ "$(step_value exit)" -eq 0 ] && break

			_status="failed in $(step_value name)"
			break
		done
		;;
	esac
	: "${_status:="ok"}"

	if step_eval -n end "$_steps" 2>/dev/null; then
		_duration="$(step_value duration)"
		_duration="$(report_duration -r "$_robsddir" -d end -t 60 "$_duration")"
	else
		_duration="$(duration_total -s "$_steps")"
		_duration="$(report_duration -r "$_robsddir" "$_duration")"
	fi

	# Add subject header.
	{
		printf 'Subject: %s: %s: ' "$_MODE" "$(hostname -s)"
		case "$_MODE" in
		robsd-cross)	cross_report_subject;;
		*)		;;
		esac
		printf '%s\n\n' "$_status"
	} >"$_tmp"

	# Add comment to the beginning of the report.
	if [ -e "${_builddir}/comment" ]; then
		cat <<-EOF >>"$_tmp"
		> comment:
		$(cat "${_builddir}/comment")

		EOF
	fi

	# Add stats to the beginning of the report.
	{
		cat <<-EOF
		> stats:
		Status: ${_status}
		Duration: ${_duration}
		Build: ${_builddir}
		EOF

		if [ -e  "${_builddir}/tags" ]; then
			printf 'Tags: '
			cat "${_builddir}/tags"
		fi

		report_sizes -r "$_robsddir" "$(release_dir "$_builddir")"
	} >>"$_tmp"

	_i=1
	while step_eval "$_i" "$_steps" 2>/dev/null; do
		_i=$((_i + 1))

		step_skip && continue

		_name="$(step_value name)"
		_exit="$(step_value exit)"
		_log="$(step_value log)"

		if [ "$_exit" -eq 0 ] &&
		   report_skip -b "$_builddir" -n "$_name" -l "$_log" \
			-t "$_tmpdir"
		then
			continue
		fi

		_duration="$(step_value duration)"

		printf '\n'
		printf '> %s:\n' "$_name"
		printf 'Exit: %d\n' "$_exit"
		printf 'Duration: %s\n' \
			"$(report_duration -d "$_name" -r "$_robsddir" "$_duration")"
		printf 'Log: %s\n' "$(basename "$_log")"
		# Honor step specific headers.
		[ -e "$_log" ] && sed -n -e 's/^X-//p' "$_log"

		report_log -e "$_exit" -n "$_name" -l "$_log" \
			-t "${_builddir}/tmp" >"${_builddir}/tmp/log"
		if [ -s "${_builddir}/tmp/log" ]; then
			trimfile "${_builddir}/tmp/log"
			echo; cat "${_builddir}/tmp/log"
		fi
		rm "${_builddir}/tmp/log"
	done >>"$_tmp"

	# smtpd(8) rejects messages with carriage return not followed by a
	# newline. Play it safe and let vis(1) encode potential carriage
	# returns.
	vis "$_tmp" >"$_report"
	rm "$_tmp"
}

# report_duration [-d step] [-t threshold] -r robsd-dir duration
#
# Format the given duration to a human readable representation.
# If option `-d' is given, the duration delta for the given step relative
# to the previous successful release is also formatted if the delta is greater
# than the given threshold.
report_duration() {
	local _d
	local _delta
	local _prev
	local _robsddir
	local _sign
	local _step=""
	local _threshold=0

	while [ $# -gt 0 ]; do
		case "$1" in
		-d)	shift; _step="$1";;
		-t)	shift; _threshold="$1";;
		-r)	shift; _robsddir="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_robsddir:?}"
	_d="$1"; : "${_d:?}"

	if [ -z "$_step" ] ||
	   ! _prev="$(duration_prev -r "$_robsddir" "$_step")"; then
		format_duration "$_d"
		return 0
	fi

	_delta=$((_d - _prev))
	if [ "$_delta" -lt 0 ]; then
		_sign="-"
		_delta=$((-_delta))
	else
		_sign="+"
	fi
	if [ "$_delta" -le "$_threshold" ]; then
		format_duration "$_d"
		return 0
	fi
	printf '%s (%s%s)\n' \
		"$(format_duration "$_d")" \
		"$_sign" \
		"$(format_duration "$_delta")"
}

# report_log -e step-exit -n step-name -l step-log -t tmp-dir
#
# Writes an excerpt of the given step log.
report_log() {
	local _exit
	local _f
	local _log
	local _name
	local _tmpdir

	case "$_MODE" in
	robsd-ports)
		ports_report_log "$@"
		return $?
		;;
	robsd-regress)
		regress_report_log "$@"
		return $?
		;;
	*)
		;;
	esac

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
	env|patch|checkflist|reboot|revert|distrib)
		cat "$_log"
		;;
	cvs)
		cat <<-EOF | while read -r _f
		${_tmpdir}/cvs-src-up.log
		${_tmpdir}/cvs-src-ci.log
		${_tmpdir}/cvs-xenocara-up.log
		${_tmpdir}/cvs-xenocara-ci.log
		EOF
		do
			[ -s "$_f" ] || continue
			cat "$_f"; echo
		done
		;;
	kernel)
		tail -n 11 "$_log"
		;;
	*)
		tail "$_log"
		;;
	esac
}

# report_size -r robsd-dir file
#
# If the given file is significantly larger than the same file in the previous
# release, a human readable representation of the size and delta is reported.
report_size() {
	local _delta
	local _f
	local _name
	local _path
	local _prev
	local _robsddir
	local _s1
	local _s2
	local _threshold

	while [ $# -gt 0 ]; do
		case "$1" in
		-r)	shift; _robsddir="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_robsddir:?}"
	_f="$1"; : "${_f:?}"

	_name="$(basename "$_f")"

	[ -e "$_f" ] || return 0

	_prev="$(prev_release -r "$_robsddir")"
	[ -z "$_prev" ] && return 0

	_path="$(release_dir "$_prev")/${_name}"
	[ -e "$_path" ] || return 0

	_s1="$(ls -l "$_f" | awk '{print $5}')"
	_s2="$(ls -l "$_path" | awk '{print $5}')"
	_delta="$((_s1 - _s2))"
	case "$_name" in
	bsd.rd)	_threshold=$((1024 * 1));;
	*)	_threshold=$((1024 * 100));;
	esac
	[ "$(abs "$_delta")" -ge "$_threshold" ] || return 0

	echo "$_name" "$(format_size "$_s1")" \
		"($(format_size -s "$_delta"))"
}

# report_sizes -r robsd-dir release-dir
#
# Report significant growth of any file present in the given release directory.
report_sizes() {
	local _dir
	local _f
	local _robsddir
	local _siz

	while [ $# -gt 0 ]; do
		case "$1" in
		-r)	shift; _robsddir="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_robsddir:?}"
	_dir="$1"; : "${_dir:?}"

	[ -d "$_dir" ] || return 0

	find "$_dir" -type f | sort | while read -r _f; do
		_siz="$(report_size -r "$_robsddir" "$_f")"
		[ -z "$_siz" ] && continue

		echo "Size: ${_siz}"
	done
}

# report_skip -b build-dir -n step-name -l step-log -t tmp-dir
#
# Exits zero if the given step should not be included in the report.
report_skip() {
	local _builddir
	local _name
	local _log

	case "$_MODE" in
	robsd-ports)
		ports_report_skip "$@"
		return $?
		;;
	robsd-regress)
		regress_report_skip "$@"
		return $?
		;;
	*)
		;;
	esac

	while [ $# -gt 0 ]; do
		case "$1" in
		-b)	shift; _builddir="$1";;
		-l)	shift; _log="$1";;
		-n)	shift; _name="$1";;
		-t)	shift;;
		*)	break;;
		esac
		shift
	done
	: "${_builddir:?}"
	: "${_log:?}"
	: "${_name:?}"

	case "$_name" in
	env|end|reboot)
		return 0
		;;
	checkflist)
		# Skip if the log only contains PS4 traces.
		grep -vq '^\+' "$_log" || return 0
		;;
	patch|revert)
		diff_list "$_builddir" "*.diff" | cmp -s - /dev/null && return 0
		;;
	*)
		;;
	esac

	return 1
}

# release_dir [-x] prefix
#
# Get the release directory with the given prefix applied.
release_dir() {
	local _prefix
	local _suffix="rel"

	while [ $# -gt 0 ]; do
		case "$1" in
		-x)	_suffix="relx";;
		*)	break;;
		esac
		shift
	done
	_prefix="$1"; : "${_prefix:?}"

	echo "${_prefix}/${_suffix}"
}

# robsd step
#
# Main loop shared between utilities.
robsd() {
	local _exit
	local _log
	local _name
	local _s
	local _step
	local _t0
	local _t1

	_step="$1"; : "${_step:?}"

	while :; do
		_name="$(step_name "$_step")"
		_s="$_step"
		_step=$((_step + 1))

		if step_eval -n "$_name" "${BUILDDIR}/steps" 2>/dev/null &&
		   step_skip; then
			info "step ${_name} skipped"
			continue
		fi
		info "step ${_name}"

		if [ "$_name" = "end" ]; then
			# The duration of the end step is the accumulated
			# duration.
			step_end -d "$(duration_total -s "${BUILDDIR}/steps")" \
				-n "$_name" -l "/dev/null" -s "$_s" \
				"${BUILDDIR}/steps"
			return 0
		fi

		_log="${BUILDDIR}/$(log_id -b "$BUILDDIR" -n "$_name" -s "$_s")"
		_exit=0
		_t0="$(date '+%s')"
		step_begin -l "$_log" -n "$_name" -s "$_s" "${BUILDDIR}/steps"
		step_exec -f "${BUILDDIR}/tmp/fail" -l "$_log" -s "$_name" ||
			_exit="$?"
		_t1="$(date '+%s')"
		step_end -d "$((_t1 - _t0))" -e "$_exit" -l "$_log" \
			-n "$_name" -s "$_s" "${BUILDDIR}/steps"

		case "$_MODE" in
		robsd-regress)
			regress_step_after -b "$BUILDDIR" -e "$_exit" \
				-n "$_name" || return 1
			;;
		*)
			[ "$_exit" -eq 0 ] || return 1
			;;
		esac

		# Reboot in progress?
		if [ "$_name" = "reboot" ] &&
		   [ "$(config_value reboot)" -eq 1 ]; then
			return 0
		fi

		# Does robsd-kill want us dead?
		lock_alive "$ROBSDDIR" "$BUILDDIR" || return 1
	done
}

# setmode mode
# setmode -p path
#
# Set the execution mode or infer it from the given program name.
setmode() {
	local _mode=""
	local _path=""

	while [ $# -gt 0 ]; do
		case "$1" in
		-p)	shift; _path="$1";;
		*)	break;;
		esac
		shift
	done

	if [ -n "$_path" ]; then
		case "${_path##*/}" in
		robsd-ports*)	_mode="robsd-ports";;
		robsd-regress*)	_mode="robsd-regress";;
		*)		_mode="robsd";;
		esac
	else
		_mode="$1"
	fi
	_MODE="$_mode"; export _MODE
}

# setprogname name
#
# Set the name of the program to be used during logging.
setprogname() {
	_PROG="$1"; export _PROG
}

# step_begin -l step-log -n step-name -s step-id file
#
# Mark the given step as about to execute by writing an entry to the given
# file. The same entry will be overwritten once the step has ended.
step_begin() {
	local _file
	local _log
	local _name
	local _s

	while [ $# -gt 0 ]; do
		case "$1" in
		-l)	shift; _log="$1";;
		-n)	shift; _name="$1";;
		-s)	shift; _s="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_log:?}"
	: "${_name:?}"
	: "${_s:?}"
	_file="$1"; : "${_file:?}"

	step_end -d -1 -e -1 -l "$_log" -n "$_name" -s "$_s" "$_file"
}

# step_end [-S] [-d duration] [-e exit] [-l step-log] -n step-name -s step-id file
#
# Mark the given step as ended by writing an entry to the given file.
step_end() {
	local _d=-1
	local _e=0
	local _log=""
	local _name
	local _s
	local _skip=0
	local _user

	while [ $# -gt 0 ]; do
		case "$1" in
		-d)	shift; _d="$1";;
		-e)	shift; _e="$1";;
		-l)	shift; _log="$1";;
		-n)	shift; _name="$1";;
		-S)	_skip="1";;
		-s)	shift; _s="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_name:?}"
	: "${_s:?}"
	_file="$1"; : "${_file:?}"

	_user="$(logname)"

	# Remove any existing entry for the same step, could be present if a
	# previous execution failed.
	[ -e "$_file" ] && sed -i -e "/step=\"${_s}\"/d" "$_file"

	# Caution: all values must be quoted and cannot contain spaces.
	{
		printf 'step="%d"\n' "$_s"
		printf 'name="%s"\n' "$_name"

		if [ "$_skip" -eq 1 ]; then
			printf 'skip="1"\n'
		else
			printf 'exit="%d"\n' "$_e"
			printf 'duration="%d"\n' "$_d"
			printf 'log="%s"\n' "$_log"
			printf 'user="%s"\n' "$_user"
			printf 'time="%d"\n' "$(date '+%s')"
		fi
	} | paste -s -d ' ' - >>"$_file"

	# Sort steps as skipped steps are added at the begining.
	mv "$_file" "${_file}.orig"
	sort -V "${_file}.orig" >"$_file"
	rm "${_file}.orig"

	# Only invoke the hook if the step has ended. A duration of -1 is a
	# sentinel indicating that the step has just begun.
	if [ "$_d" -ne -1 ] &&
	   [ "$_name" != "env" ]; then
		# Ignore non-zero exit.
		"$ROBSDHOOK" -m "$_MODE" -V ${ROBSDCONF:+"-f${ROBSDCONF}"} \
			-v "builddir=${BUILDDIR}" \
			-v "exit=${_e}" \
			-v "step=${_name}" \
			|| :
	fi
}

# step_eval offset file
# step_eval -offset file
# step_eval -n step-name file
#
# Read the given step from file into the _STEP array. The offset argument
# refers to a line in file. A negative offset starts from the end of file.
step_eval() {
	local _file
	local _i
	local _k
	local _n
	local _name=0
	local _next
	local _step
	local _v

	while [ $# -gt 0 ]; do
		case "$1" in
		-n)	_name=1;;
		*)	break;;
		esac
		shift
	done
	_step="$1"; : "${_step:?}"
	_file="$2"; : "${_file:?}"

	set -A _STEP

	if ! [ -e "$_file" ]; then
		echo "step_eval: ${_file}: no such file" 1>&2
		return 1
	fi

	if [ "$_name" -eq 1 ]; then
		_line="$(grep -e "name=\"${_step}\"" "$_file" || :)"
	elif [ "$_step" -lt 0 ]; then
		_n="$(wc -l "$_file" | awk '{print $1}')"
		[ $((- _step)) -gt "$_n" ] && return 1
		_line="$(tail "$_step" "$_file" | head -1)"
	else
		_line="$(sed -n -e "${_step}p" "$_file")"
	fi
	if [ -z "$_line" ]; then
		echo "step_eval: ${_file}: step ${_step} not found" 1>&2
		return 1
	fi

	while :; do
		_next="${_line%% *}"
		_k="${_next%=*}"
		_v="${_next#*=\"}"; _v="${_v%\"}"

		_i="$(step_field "$_k")"
		if [ "$_i" -lt 0 ]; then
			echo "step_eval: ${_file}: unknown field ${_k}" 1>&2
			return 1
		fi
		_STEP[$_i]="$_v"

		_next="${_line#* }"
		if [ "$_next" = "$_line" ]; then
			break
		else
			_line="$_next"
		fi
	done

	if [ ${#_STEP[*]} -eq 0 ]; then
		return 1
	else
		return 0
	fi
}

# step_exec [-X] -f fail -l log -s step
#
# Execute the given script and redirect any output to log.
step_exec() (
	local _err=0
	local _exec
	local _fail
	local _log
	local _robsdexec="${ROBSDEXEC:-${EXECDIR}/${_MODE}-exec}"
	local _step
	local _trace="yes"

	while [ $# -gt 0 ]; do
		case "$1" in
		-X)	_trace="";;
		-f)	shift; _fail="$1";;
		-l)	shift; _log="$1";;
		-s)	shift; _step="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_fail:?}"
	: "${_log:?}"
	: "${_step:?}"

	_exec="${EXECDIR}/${_MODE}-${_step}.sh"
	if ! [ -e "$_exec" ]; then
		_exec="${EXECDIR}/robsd-${_step}.sh"
	fi

	[ "$DETACH" -eq 0 ] || exec >/dev/null 2>&1

	{
		if [ "$_MODE" = "robsd-regress" ] && ! [ -e "$_exec" ]; then
			"$_robsdexec" sh -eu ${_trace:+-x} \
				"${EXECDIR}/${_MODE}-exec.sh" "$_step" ||
				echo "$?" >"$_fail"

			# Regress tests can fail but still exit zero, check the
			# log for failures.
			regress_failed "$_log" && echo 1 >"$_fail"
		else
			"$_robsdexec" sh -eu ${_trace:+-x} "$_exec" ||
				echo "$?" >"$_fail"
		fi
	} </dev/null 2>&1 | tee "$_log"
	if [ -e "$_fail" ]; then
		_err="$(<"$_fail")"
		rm -f "$_fail"
	fi
	return "$_err"
)

# step_failures file
#
# Get the number of failing steps.
step_failures() {
	local _file

	_file="$1"; : "${_file:?}"

	grep -c 'exit="[^0]*"' "$_file" || :
}

# step_field step-name
#
# Get the corresponding _STEP array index for the given field name.
step_field() {
	local _name

	_name="$1"; : "${_name:?}"

	case "$_name" in
	step)		echo 0;;
	name)		echo 1;;
	exit)		echo 2;;
	duration)	echo 3;;
	log)		echo 4;;
	time)		echo 5;;
	user)		echo 6;;
	skip)		echo 7;;
	*)		echo -1;;
	esac
}

# step_id step-name
#
# Resolve the given step name to its corresponding numeric id.
step_id() {
	local _id
	local _name

	_name="$1"; : "${_name:?}"

	_id="$(steps | cat -n | grep -w "$_name" | awk '{print $1}')"
	if [ -n "$_id" ]; then
		echo "$_id"
	else
		echo "step_id: ${_name}: unknown step" 1>&2
		return 1
	fi
}

# step_name step-id
#
# Resolve the given numeric step to its corresponding name.
step_name() {
	local _step

	_step="$(steps | sed -n -e "${1}p")"
	if [ -n "$_step" ]; then
		echo "$_step"
	else
		return 1
	fi
}

# steps
#
# Get the names of all steps in execution order.
# The last step named end is a sentinel step without a corresponding step
# script.
steps() {
	case "$_MODE" in
	robsd)
		cat <<-EOF
		env
		cvs
		patch
		kernel
		reboot
		env
		base
		release
		checkflist
		xbase
		xrelease
		image
		hash
		revert
		distrib
		end
		EOF
		;;
	robsd-cross)
		cross_steps
		;;
	robsd-ports)
		ports_steps
		;;
	robsd-regress)
		regress_steps
		;;
	*)
		;;
	esac
}

# step_next file
#
# Get the next step to execute. If the last step failed or aborted, it will be
# executed again. The exception also applies to the end step, this is useful
# since it allows the report to be regenerated for a finished release.
step_next() {
	local _exit
	local _file
	local _i=1
	local _step

	_file="$1"; : "${_file:?}"

	while step_eval "-${_i}" "$_file"; do
		_i="$((_i + 1))"

		# The skip field is optional, suppress errors.
		if [ "$(step_value skip 2>/dev/null)" -eq 1 ]; then
			continue
		fi

		_step="$(step_value step)"
		_exit="$(step_value exit)"
		if [ "$_exit" -ne 0 ]; then
			echo "$_step"
		elif [ "$(step_value name)" = "end" ]; then
			echo "$_step"
		else
			echo $((_step + 1))
		fi
		return 0
	done

	echo "step_next: cannot find next step" 1>&2
	return 1
}

# step_skip
#
# Exits zero if the step has been skipped.
step_skip() {
	local _skip

	# The skip field is optional, suppress errors.
	_skip="$(step_value skip 2>/dev/null)"
	[ "$_skip" -eq 1 ]
}

# step_value field-name
#
# Get corresponding value for the given field name in the global _STEP array.
step_value() {
	local _name
	local _i

	_name="$1"; : "${_name:?}"

	_i="$(step_field "$_name")"
	if [ "$_i" -lt 0 ] || ! echo "${_STEP[$_i]}" >/dev/null 2>&1; then
		echo "step_value: ${_name}: unknown field" 1>&2
		return 1
	fi
	echo "${_STEP[$_i]}"
}

# trap_exit -r robsd-dir [-b build-dir] [-s stat-pid]
#
# Exit trap handler. The log dir may not be present if we failed very early on.
trap_exit() {
	local _err="$?"
	local _builddir=""
	local _robsddir=""
	local _statpid=""

	info "trap exit ${_err}"

	while [ $# -gt 0 ]; do
		case "$1" in
		-r)	shift; _robsddir="$1";;
		-b)	shift; _builddir="$1";;
		-s)	shift; _statpid="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_robsddir:?}"

	[ -z "$_statpid" ] || kill "$_statpid" || :

	[ -n "$_builddir" ] || return "$_err"

	lock_release "$_robsddir" "$_builddir" || :

	# Generate the report if a step failed or the end step is reached.
	if [ "$_err" -ne 0 ] ||
	   step_eval -n end "${_builddir}/steps" 2>/dev/null
	then
		if report -r "$_robsddir" -b "$_builddir" &&
		   [ "$DETACH" -ne 0 ]; then
			# Do not send mail during interactive invocations.
			sendmail root <"${_builddir}/report"
		fi
	fi

	# Do not leave an empty build around.
	[ -s "${_builddir}/steps" ] || rm -r "$_builddir"

	return "$_err"
}

# trimfile path
#
# Remove empty lines at the end of the given file.
trimfile() {
	local _path

	_path="$1"; : "${_path:?}"
	while [ "$(sed -n -e '$p' "$_path")" = "" ]; do
		sed -i -e '$d' "$_path"
	done
}

# unpriv user utility argument ...
# unpriv user
#
# Run utility or stdin as the given user.
unpriv() (
	local _user

	_user="$1"; : "${_user:?}"; shift

	# Since robsd is running as root, su(1) will preserve the following
	# environment variables which is unwanted by especially some regress
	# tests.
	LOGNAME="$_user"
	USER="$_user"
	if [ $# -gt 0 ]; then
		su "$_user" -c "$@"
	else
		su "$_user" -sx
	fi
)
