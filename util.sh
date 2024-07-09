# abs number
#
# Get the absolute value of the given number.
abs() {
	local _n

	_n="$1"; : "${_n:?}"

	: "${_n:?}"

	if [ "${_n}" -lt 0 ]; then
		echo "$((- _n))"
	else
		echo "${_n}"
	fi
}

# build_date -b build-dir
#
# Get the release build start date.
build_date() {
	local _builddir

	while [ $# -gt 0 ]; do
		case "$1" in
		-b)	shift; _builddir="$1";;
		*)	;;
		esac
		shift
	done
	: "${_builddir:?}"

	step_eval 1 "$(step_path "${_builddir}")"
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
	printf '%s.%d\n' "${_d}" "$((_c + 1))"
}

# build_init build-dir
#
# Initialize the given build directory.
build_init() {
	local _builddir
	local _steps

	_builddir="$1"; : "${_builddir:?}"
	_steps="$(step_path "${_builddir}")"

	[ -d "${_builddir}" ] || mkdir "${_builddir}"
	[ -d "${_builddir}/tmp" ] || mkdir "${_builddir}/tmp"
	[ -e "${_builddir}/robsd.log" ] || : >"${_builddir}/robsd.log"
	[ -e "${_steps}" ] || : >"${_steps}"
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
	if [ -z "${_perf}" ] || [ "${_perf}" -eq 100 ]; then
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
                find "${_d}" -mindepth 1 -maxdepth 1 -print0 | xargs -0r rm -r
	done
}

# config_load [robsd-config-argument ...]
#
# Load and validate the configuration.
# shellcheck disable=SC2120
config_load() {
	local _err=0
	local _tmp

	: "${BUILDDIR:=}"
	: "${DETACH:=1}"
	: "${EXECDIR:=/usr/local/libexec/robsd}"; export EXECDIR
	: "${ROBSDCLEAN:=/usr/local/sbin/robsd-clean}"
	: "${ROBSDCONFIG:=${EXECDIR}/robsd-config}"
	: "${ROBSDEXEC:=${EXECDIR}/robsd-exec}"
	: "${ROBSDHOOK:=${EXECDIR}/robsd-hook}"
	: "${ROBSDLS:=${EXECDIR}/robsd-ls}"
	: "${ROBSDREPORT:=${EXECDIR}/robsd-report}"
	: "${ROBSDSTAT:=${EXECDIR}/robsd-stat}"
	: "${ROBSDSTEP:=${EXECDIR}/robsd-step}"
	: "${ROBSDWAIT:=${EXECDIR}/robsd-wait}"

	_tmp="$(mktemp -t robsd.XXXXXX)"
	{
		cat
	} | "${ROBSDCONFIG}" -m "${_MODE}" ${ROBSDCONF:+"-C${ROBSDCONF}"} "$@" - \
		>"${_tmp}" || _err="$?"
	[ "${_err}" -eq 0 ] && eval "$(<"${_tmp}")"
	rm "${_tmp}"
	[ "${_err}" -eq 0 ] || return "${_err}"

	case "${_MODE}" in
	robsd|robsd-cross)
		MAKEFLAGS="-j$(config_value ncpu)"; export MAKEFLAGS
		;;
	robsd-ports)
		ports_config_load
		;;
	robsd-regress)
		regress_config_load
		;;
	canvas)
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

	echo "\${${_var}}" |
	"${ROBSDCONFIG}" -m "${_MODE}" ${ROBSDCONF:+"-C${ROBSDCONF}"} -
}

# cvs_changelog -t tmp-dir
#
# Get CVS changes.
cvs_changelog() {
	local _tmpdir

	while [ $# -gt 0 ]; do
		case "$1" in
		-t)	shift; _tmpdir="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_tmpdir:?}"

	cat <<-EOF | while read -r _f
	${_tmpdir}/cvs-src-up.log
	${_tmpdir}/cvs-src-ci.log
	${_tmpdir}/cvs-xenocara-up.log
	${_tmpdir}/cvs-xenocara-ci.log
	EOF
	do
		[ -s "${_f}" ] || continue
		cat "${_f}"; echo
	done
}

# cvs_field field log-line
#
# Extract the given field from a cvs log line.
cvs_field() {
	local _field
	local _line

	_field="$1"; : "${_field:?}"
	_line="$2"; : "${_line:?}"

	echo "${_line}" | grep -q -F "${_field}" || return 1

	_line="${_line##*"${_field}": }"; _line="${_line%%;*}"
	echo "${_line}"
}

# cvs_date -b build-dir -s steps
#
# Get the date of the CVS step expressed as a Unix timestamp for the given
# invocation.
cvs_date() {
	local _builddir
	local _log
	local _steps

	while [ $# -gt 0 ]; do
		case "$1" in
		-b)	shift; _builddir="$1";;
		-s)	shift; _steps="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_builddir:?}"
	: "${_steps:?}"

	step_eval -n cvs "${_steps}"
	step_skip && return 1

	# Try to find the date of the last revision in the log, i.e. the first
	# entry written by cvs_log(). If nothing was updated, use the step
	# execution date of the cvs step as a fallback.
	_log="${_builddir}/$(step_value log 2>/dev/null || :)"
	_date="$(grep -m 1 '^Date:' "${_log}" | sed -e 's/^[^:]*: *//' || :)"
	if [ -n "${_date}" ]; then
		date -j -f '%Y/%m/%d %H:%M:%S' '+%s' "${_date}"
	else
		step_value time
	fi
}

# cvs_log -t tmp-dir -c cvs-dir -h cvs-host -u cvs-user
#
# Generate a descending log of all commits since the last release build for the
# given repository. Individual revisions are group by commit id and sorted by
# date.
cvs_log() {
	local _date=""
	local _cid
	local _indent="  "
	local _line
	local _log
	local _message=0
	local _path
	local _prev
	local _repo
	local _tmp
	local _user

	while [ $# -gt 0 ]; do
		case "$1" in
		-t)	shift; _tmp="$1";;
		-c)	shift; _repo="$1";;
		-h)	shift; _host="$1";;
		-u)	shift; _user="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_tmp:?}"
	: "${_repo:?}"
	: "${_host:?}"
	: "${_user:?}"

	[ -d "${_tmp}" ] && rm -r "${_tmp}"
	mkdir -p "${_tmp}"

	# Use the date from latest revision from the previous release.
	for _prev in $(prev_release -B); do
		_date="$(cvs_date -b "${_prev}" -s "$(step_path "${_prev}")")" && break
	done
	if [ -z "${_date}" ]; then
		echo "cvs_log: previous date not found" 1>&2
		return 0
	fi
	_date="$(date -r "${_date}" '+%F %T')"

	grep '^[MPU]\>' |
	cut -d ' ' -f 2 |
	unpriv "${_user}" "cd ${_repo} && xargs cvs -q -d ${_host} log -N -l -d '>${_date}'" |
	tee "${_tmp}/cvs.log" |
	while read -r _line; do
		case "${_line}" in
		Working\ file:*)
			_path="${_line#*: }"
			;;
		date:*)
			_date="$(cvs_field date "${_line}")"
			_cid="$(cvs_field commitid "${_line}")" || continue
			if ! [ -d "${_tmp}/${_cid}" ]; then
				mkdir "${_tmp}/${_cid}"
				cvs_field author "${_line}" >"${_tmp}/${_cid}/author"
				_message=1
			fi
			echo "${_date}" >>"${_tmp}/${_cid}/date"
			echo "${_indent}${_path}" >>"${_tmp}/${_cid}/files"
			;;
		-[-]*|=[=]*)
			_message=0
			;;
		*)
			if [ "${_message}" -eq 1 ]; then
				echo "${_indent}${_line}" >>"${_tmp}/${_cid}/message"
			fi
			;;
		esac
	done

	# Sort each commit using the date file.
	find "${_tmp}" -type f -name date |
	while read -r _p; do
		_date="$(sort -nr "${_p}" | head -1)"
		echo "${_date} ${_p%/*}"
	done |
	sort -nr |
	while read -r _date _time _path; do
		echo "commit ${_path##*/}"
		echo -n "Author: "
		cat "${_path}/author"
		echo "Date: ${_date} ${_time}"
		echo
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

	_root="$(diff_root -d "${_dir}" "${_diff}")"
	cd "${_root}"

	# Try to revert the diff if dry run fails.
	if ! unpriv "${_user}" "exec patch -C -Efs" <"${_diff}" >/dev/null; then
		unpriv "${_user}" "exec patch -R -Efs" <"${_diff}"
	fi
	# Use the strip argument in order to cope with files in newly created
	# directories since they would otherwise end up in the current working
	# directory. However, we could operate on a Git diff in which prefixes
	# must be stripped.
	for _strip in 0 1; do
		if unpriv "${_user}" "exec patch -Efs -p ${_strip}" \
		   <"${_diff}" >"${_tmp}" 2>&1; then
			break
		fi
	done
	[ -s "${_tmp}" ] && _err=1
	cat "${_tmp}"
	rm -f "${_tmp}"
	return "${_err}"
)

# diff_clean dir
#
# Remove leftovers from cvs and patch in dir.
diff_clean() {
	local _dir
	local _path

	_dir="$1"; : "${_dir:?}"

	find "${_dir}" -type f \( \
		-name '*.orig' -o -name '*.rej' -o -name '.#*' \) |
	while read -r _path; do
		if ! grep -sq "^/${_path##*/}/" "${_path%/*}/CVS/Entries"; then
			echo "${_path}"
		fi
	done |
	xargs -r rm
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

		_r="$(diff_root -d "${_root}" "${_src}")"
		info "using diff ${_src} rooted in ${_r}"

		{
			if ! head -1 "${_src}" | grep -q '^#'; then
				printf '# %s\n\n' "${_src}"
			fi
			cat "${_src}"
		} >"${_dst}"
		chmod 644 "${_dst}"

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

	find "${_builddir}" -maxdepth 1 -type f -name "${_prefix}.*" | sort
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

	_root="$(diff_root -d "${_dir}" "${_diff}")"
	cd "${_root}"

	if unpriv "${_user}" "exec patch -CR -Efs" <"${_diff}" >/dev/null 2>&1; then
		info "reverting diff ${_diff}"
		unpriv "${_user}" "exec patch -R -Ef" <"${_diff}" >"${_revert}"
	else
		info "diff already reverted ${_diff}"
	fi
	if [ -e "${_revert}" ]; then
		diff_clean "${_dir}"

		# Remove empty directories.
		sed -n -e 's/^Removing \([^[:space:]]*\) (empty .*/\1/p' "${_revert}" |
		xargs -r -L 1 dirname |
		sort |
		uniq |
		while read -r _p; do
			isempty "${_p}" || continue
			info "removing empty directory ${_root}/${_p}"
			rmdir "${_p}"
		done
	fi
	rm -f "${_revert}"
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
		while [ -n "${_p}" ]; do
			if [ -e "${_root}${_p}" ]; then
				echo "${_root}${_p}"
				_err=0
				break
			fi

			_p="$(path_strip "${_p}")"
		done

		return "${_err}"
	done || echo "${_root}"

	return 0
}

# duration_prev step-name
#
# Get the duration for the given step from the previous successful invocation.
# Exits non-zero if no previous invocation exists or the previous one failed.
duration_prev() {
	local _duration
	local _exit
	local _prev
	local _step

	_step="$1"; : "${_step:?}"

	prev_release -B |
	while read -r _prev; do
		step_eval -n "${_step}" "$(step_path "${_prev}")" 2>/dev/null || continue
		step_skip && continue

		_exit="$(step_value exit 2>/dev/null || echo 1)"
		[ "${_exit}" -eq 0 ] || continue

		_duration="$(step_value duration 2>/dev/null)" || continue
		echo "${_duration}"
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

	case "${_MODE}" in
	robsd-regress)
		regress_duration_total -s "${_steps}"
		return 0
		;;
	*)
		;;
	esac

	while step_eval "${_i}" "${_steps}" 2>/dev/null; do
		_i=$((_i + 1))

		step_skip && continue

		# Do not include the previous accumulated build duration.
		# Could be present if the report is re-generated.
		[ "$(step_value name)" = "end" ] && continue

		_d="$(step_value duration)"
		_tot=$((_tot + _d))
	done

	echo "${_tot}"
}

# fatal message ...
#
# Print the given message to stderr and exit non-zero.
fatal() {
	info "$*" 1>&2
	exit 1
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
	echo "${_PROG}: ${*}" | tee -a "${_log}"
}

# isempty path
#
# Exits zero if the given file or directory is empty.
isempty() {
	local _path

	_path="$1"; : "${_path:?}"
	! find "${_path}" -empty | cmp -s - /dev/null
}

# jobs_count job ...
#
# Get the number of running jobs
jobs_count() (
	# shellcheck disable=SC2068
	set -- $@
	echo "$#"
)

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
	if [ -n "${_owner}" ] && [ "${_owner}" != "${_builddir}" ]; then
		info "${_owner}: lock already acquired"
		return 1
	fi

	echo "${_builddir}" >"${_rootdir}/.running"
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
	echo "${_builddir}" | cmp -s - "${_rootdir}/.running"
}

# lock_release root-dir build-dir
#
# Release the mutex lock if we did acquire it.
lock_release() {
	local _builddir
	local _rootdir

	_rootdir="$1"; : "${_rootdir:?}"
	_builddir="$2"; : "${_builddir:?}"

	if echo "${_builddir}" | cmp -s - "${_rootdir}/.running"; then
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

	_name="$(echo "${_name}" | tr '/' '-')"
	_id="$(printf '%03d-%s.log' "${_step}" "${_name}")"
	_dups="$(find "${_builddir}" -name "${_id}*" | wc -l)"
	if [ "${_dups}" -gt 0 ]; then
		printf '%s.%d' "${_id}" "${_dups}"
	else
		echo "${_id}"
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
	[ "${_dst#*/}" = "${_dst}" ] && return 0
	echo "/${_dst#*/}"

}

# prev_release [-- robsd-ls-argument ...]
#
# Get previous invocations.
prev_release() {
	"${ROBSDLS}" -m "${_MODE}" ${ROBSDCONF:+"-C${ROBSDCONF}"} "$@"
}

# purge [-d] dir count
#
# Keep the latest count number of release directories in dir.
# The older ones will be moved to the keep-dir, preserving only the relevant
# files. All purged directories are written to stdout.
purge() {
	local _attic
	local _d
	local _dir
	local _dry=0
	local _dst
	local _n
	local _tim

	while [ $# -gt 0 ]; do
		case "$1" in
		-d)	_dry=1;;
		*)	break;;
		esac
		shift
	done
	_dir="$1"; : "${_dir:?}"
	_n="$2"; : "${_n:?}"

	_attic="$(config_value keep-dir)"

	# While not running, must compensate for current builddir not being
	# excluded by robsd-ls.
	if ! config_value builddir >/dev/null 2>&1; then
		_n="$((_n + 1))"
	fi

	prev_release -B |
	tail -n "+${_n}" |
	while read -r _d; do
		if [ "${_dry}" -eq 1 ]; then
			echo "${_d}"
			continue
		fi

		[ -d "${_attic}" ] || mkdir "${_attic}"

		# Grab the modification time before removal of irrelevant files.
		_tim="$(stat -f '%Sm' -t '%FT%T' "${_d}")"

		rm -rf "${_d}/tmp"
		find "${_d}" -mindepth 1 -not \( \
			-name '*.diff.*' -o \
			-name 'comment' -o \
			-name 'index.txt' -o \
			-name 'report' -o \
			-name 'stat.csv' -o \
			-name 'step.csv' -o \
			-name 'tags' \) -delete

		# Transform: YYYY-MM-DD.X -> YYYY/MM/DD.X
		_dst="${_attic}/$(echo "${_d##*/}" | tr '-' '/')"
		# Create leading YYYY/MM directories.
		mkdir -p "${_dst%/*}"
		cp -pr "${_d}" "${_dst}"
		touch -d "${_tim}" "${_dst}"
		rm -r "${_d}"
		echo "${_d}"
	done
}

# report -b build-dir
#
# Create and save report.
report() {
	local _builddir
	local _report

	while [ $# -gt 0 ]; do
		case "$1" in
		-b)	shift; _builddir="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_builddir:?}"

	_report="${_builddir}/report"

	"${ROBSDREPORT}" -m "${_MODE}" ${ROBSDCONF:+-C ${ROBSDCONF}} "${_builddir}" >"${_report}"
}

# report_receiver -b build-dir
#
# Get report mail receiver.
report_receiver() {
	local _builddir
	local _steps

	while [ $# -gt 0 ]; do
		case "$1" in
		-b)	shift; _builddir="${1}";;
		*)	break;;
		esac
		shift
	done
	: "${_builddir:?}"

	_steps="$(step_path "${_builddir}")"

	case "${_MODE}" in
	canvas)
		step_eval 1 "${_steps}"
		step_value user
		;;
	*)
		echo root
		;;
	esac
}

# robsd -b build-dir -s step-id
#
# Main loop shared between utilities.
robsd() {
	local _d0
	local _d1
	local _jobs=""
	local _name
	local _ncpu
	local _parallel
	local _step
	local _steps

	while [ $# -gt 0 ]; do
		case "$1" in
		-b)	shift; _builddir="$1";;
		-s)	shift; _step="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_builddir:?}"
	: "${_step:?}"

	_ncpu="$(config_value ncpu)"
	_steps="$(step_path "${_builddir}")"

	steps -o "${_step}" | while read -r _step _name _parallel; do
		if step_eval -n "${_name}" "${_steps}" 2>/dev/null &&
		   step_skip; then
			info "step ${_name} skipped"
			continue
		fi
		info "step ${_name}"

		if [ -n "${_parallel}" ]; then
			# Ensure the job queue is not full.
			if [ "$(jobs_count "${_jobs}")" -eq "${_ncpu}" ]; then
				info "parallel wait $(jobs_count "${_jobs}")/${_ncpu}"
				_jobs="$(echo "${_jobs}" | xargs "${ROBSDWAIT}" | xargs)"
			fi

			# Execute job in parallel.
			step_exec_job -b "${_builddir}" -s "${_steps}" \
				-i "${_step}" -n "${_name}" &
			_jobs="${_jobs}${_jobs:+ }${!}"
			info "parallel jobs $(jobs_count "${_jobs}")/${_ncpu}"
		else
			# Wait for all running jobs to finish.
			if [ -n "${_jobs}" ]; then
				info "parallel barrier $(jobs_count "${_jobs}")/${_ncpu}"
				echo "${_jobs}" | xargs "${ROBSDWAIT}" -a
				_jobs=""
			fi

			if [ "${_name}" = "end" ]; then
				# The duration of the end step is the
				# accumulated duration.
				_d1="$(duration_total -s "${_steps}")"
				_d0="$(duration_prev "${_name}" || :)"
				if [ -n "${_d0}" ]; then
					_delta="$((_d1 - _d0))"
				else
					_delta=0
				fi
				step_write -t -s "${_step}" -n "${_name}" -e 0 \
					-d "${_d1}" -a "${_delta}" "${_steps}"
				# The hook is invoked as late as possible in the
				# exit trap handler.
				return 0
			fi

			# Execute job synchronously.
			step_exec_job -b "${_builddir}" -s "${_steps}" \
				-i "${_step}" -n "${_name}"
		fi

		# Reboot in progress?
		if [ "${_name}" = "reboot" ] &&
		   [ "$(config_value reboot)" -eq 1 ]; then
			return 0
		fi

		# Does robsd-kill want us dead?
		if ! lock_alive "${ROBSDDIR}" "${_builddir}"; then
			[ -z "${_jobs}" ] || echo "${_jobs}" | xargs "${ROBSDWAIT}" -a
			return 1
		fi
	done
}

# robsd_hook [robsd-hook-argument ...]
#
# Invoke robsd hook.
robsd_hook() {
	# Ignore non-zero exit.
	"${ROBSDHOOK}" -m "${_MODE}" -V ${ROBSDCONF:+"-C${ROBSDCONF}"} "$@" || :
}

# setmode mode
#
# Set the execution mode.
setmode() {
	local _mode=""

	_mode="$1"; : "${_mode:?}"

	_MODE="${_mode}"; export _MODE
}

# setprogname name
#
# Set the name of the program to be used during logging.
setprogname() {
	_PROG="$1"; export _PROG
}

# step_write [-S] [-t] [-l step-log] [-a delta]
#            -s step-id -n step-name -e exit -d duration file
step_write() {
	local _delta=0
	local _duration
	local _exit
	local _log=""
	local _name
	local _s
	local _skip=0
	local _time=""
	local _user

	while [ $# -gt 0 ]; do
		case "$1" in
		-a)	shift; _delta="$1";;
		-S)	_skip="1";;
		-t)	_time="$(date +%s)";;
		-d)	shift; _duration="$1";;
		-e)	shift; _exit="$1";;
		-l)	shift; _log="$1";;
		-n)	shift; _name="$1";;
		-s)	shift; _s="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_s:?}"
	: "${_name:?}"
	: "${_exit:?}"
	: "${_duration:?}"
	_file="$1"; : "${_file:?}"

	_user="$(logname)"

	"${ROBSDSTEP}" -W -f "${_file}" -i "${_s}" -- \
		"name=${_name}" \
		"exit=${_exit}" \
		"duration=${_duration}" \
		${_delta:+delta=${_delta}} \
		${_log:+log=${_log}} \
		"user=${_user}" \
		${_time:+time=${_time}} \
		"skip=${_skip}"
}

# has_steps file
#
# Returns zero if the given step file is not empty.
has_steps() {
	local _file
	local _i=1

	_file="$1"; : "${_file:?}"

	while step_eval "${_i}" "${_file}" 2>/dev/null; do
		_i="$((_i + 1))"

		if [ "$(step_value skip)" -eq 1 ]; then
			continue
		else
			return 0
		fi
	done

	return 1
}

# step_eval offset file
# step_eval -offset file
# step_eval -n step-name file
#
# Read the given step using robsd-step into distinct variables for each field.
step_eval() {
	local _err=0
	local _file
	local _flag="-i"
	local _step
	local _tmp

	while [ $# -gt 0 ]; do
		case "$1" in
		-n)	_flag="-n";;
		*)	break;;
		esac
		shift
	done
	_step="$1"; : "${_step:?}"
	_file="$2"; : "${_file:?}"

	_tmp="$(mktemp -t robsd.XXXXXX)"
	{
		# shellcheck disable=SC2016
		printf '_STEP_step=${step}\n'
		# shellcheck disable=SC2016
		printf '_STEP_name=${name}\n'
		# shellcheck disable=SC2016
		printf '_STEP_exit=${exit}\n'
		# shellcheck disable=SC2016
		printf '_STEP_duration=${duration}\n'
		# shellcheck disable=SC2016
		printf '_STEP_log=${log}\n'
		# shellcheck disable=SC2016
		printf '_STEP_time=${time}\n'
		# shellcheck disable=SC2016
		printf '_STEP_user=${user}\n'
		# shellcheck disable=SC2016
		printf '_STEP_skip=${skip}\n'
		# shellcheck disable=SC2016
		printf '_STEP_delta=${delta}\n'
	} | "${ROBSDSTEP}" -R -f "${_file}" "${_flag}" "${_step}" >"${_tmp}" || _err="$?"
	[ "${_err}" -eq 0 ] && eval "$(<"${_tmp}")"
	rm "${_tmp}"
	return "${_err}"
}

# step_exec [-X] -l log -s step
#
# Execute the given script and redirect any output to log.
step_exec() (
	local _err
	local _fail
	local _log
	local _step
	local _trace="yes"
	local _tmpdir

	while [ $# -gt 0 ]; do
		case "$1" in
		-X)	_trace="";;
		-l)	shift; _log="$1";;
		-s)	shift; _step="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_log:?}"
	: "${_step:?}"

	_tmpdir="$(config_value tmp-dir)"
	_fail="$(mktemp -p "${_tmpdir}" step-exec.XXXXXX)"
	echo 0 >"${_fail}"

	[ "${DETACH}" -eq 0 ] || exec >/dev/null 2>&1

	{
		"${ROBSDEXEC}" -m "${_MODE}" ${ROBSDCONF:+"-C${ROBSDCONF}"} \
			${_trace:+-x} "${_step}" || echo "$?" >"${_fail}"

		if [ "${_MODE}" = "robsd-regress" ]; then
			# Regress tests can fail but still exit zero, check the
			# log for failures.
			regress_failed "${_log}" && echo 1 >"${_fail}"
		fi
	} </dev/null 2>&1 | tee "${_log}"
	_err="$(<"${_fail}")"
	rm -f "${_fail}"
	return "${_err}"
)

# step_exec_job -b build-dir -s steps -i step-id -n step-name
#
# Execute a single step.
step_exec_job() {
	local _builddir
	local _d0
	local _d1
	local _delta
	local _exit=0
	local _id
	local _log
	local _name
	local _steps
	local _t0
	local _t1

	while [ $# -gt 0 ]; do
		case "$1" in
		-b)	shift; _builddir="$1";;
		-s)	shift; _steps="$1";;
		-i)	shift; _id="$1";;
		-n)	shift; _name="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_builddir:?}"
	: "${_id:?}"
	: "${_name:?}"
	: "${_steps:?}"

	_log="$(log_id -b "${_builddir}" -n "${_name}" -s "${_id}")"
	_t0="$(date '+%s')"
	step_write -t -l "${_log}" -s "${_id}" -n "${_name}" -e -1 -d -1 "${_steps}"
	step_exec -l "${_builddir}/${_log}" -s "${_name}" || _exit="$?"
	_t1="$(date '+%s')"
	_d1="$((_t1 - _t0))"
	_d0="$(duration_prev "${_name}" || :)"
	if [ -n "${_d0}" ]; then
		_delta="$((_d1 - _d0))"
	else
		_delta=0
	fi
	step_write -l "${_log}" -s "${_id}" -n "${_name}" -e "${_exit}" -d "${_d1}" \
		-a "${_delta}" "${_steps}"

	robsd_hook -v "step-exit=${_exit}" -v "step-name=${_name}"

	case "${_MODE}" in
	robsd-regress)
		regress_step_after -b "${_builddir}" -e "${_exit}" -n "${_name}" || return 1
		;;
	*)
		[ "${_exit}" -eq 0 ] || return 1
		;;
	esac
}

# step_id step-name
#
# Resolve the given step name to its corresponding numeric id.
step_id() {
	local _id
	local _name

	_name="$1"; : "${_name:?}"

	_id="$(steps | grep -w "${_name}" | cut -d ' ' -f 1)"
	if [ -n "${_id}" ]; then
		echo "${_id}"
	else
		echo "step_id: ${_name}: unknown step" 1>&2
		return 1
	fi
}

# step_path build-dir
#
# Get the path to the steps file.
step_path() {
	local _dir

	_dir="$1"; : "${_dir:?}"
	echo "${_dir}/step.csv"
}

# steps [robsd-step-argument ...]
#
# Get steps in execution order.
steps() {
	"${ROBSDSTEP}" -L -m "${_MODE}" ${ROBSDCONF:+"-C${ROBSDCONF}"} "$@"
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

	while step_eval "-${_i}" "${_file}"; do
		_i="$((_i + 1))"

		# The skip field is optional, suppress errors.
		if [ "$(step_value skip 2>/dev/null)" -eq 1 ]; then
			continue
		fi

		_step="$(step_value step)"
		_exit="$(step_value exit)"
		if [ "${_exit}" -ne 0 ]; then
			echo "${_step}"
		elif [ "$(step_value name)" = "end" ]; then
			echo "${_step}"
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
	[ "${_skip}" -eq 1 ]
}

# step_value field-name
#
# Get corresponding value for the given step field name.
step_value() {
	local _name

	_name="$1"; : "${_name:?}"

	if ! (eval "echo \${_STEP_${_name}}") 2>/dev/null; then
		echo "step_value: ${_name}: unknown field" 1>&2
		return 1
	fi
}

# trap_exit -r robsd-dir [-b build-dir] [-s stat-pid]
#
# Exit trap handler. The build dir may not be present if we failed very early on.
trap_exit() {
	local _err="$?"
	local _builddir=""
	local _receiver=
	local _robsddir=""
	local _statpid=""
	local _steps

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

	[ -z "${_statpid}" ] || kill "${_statpid}" || :

	[ -n "${_builddir}" ] || return "${_err}"

	_steps="$(step_path "${_builddir}")"

	# Generate the report if a step failed or the end step is reached.
	if has_steps "${_steps}" &&
	   { [ "${_err}" -ne 0 ] || step_eval -n end "${_steps}" 2>/dev/null; }
	then
		# Do not send mail during interactive invocations.
		if report -b "${_builddir}" &&
		   [ "${DETACH}" -ne 0 ]; then
			_receiver="$(report_receiver -b "${_builddir}")"
			sendmail "${_receiver}" <"${_builddir}/report"
		fi
	fi

	if step_eval -n end "${_steps}" 2>/dev/null; then
		robsd_hook -v "step-exit=0" -v "step-name=end"
	fi

	lock_release "${_robsddir}" "${_builddir}" || :

	# Do not leave an empty build around.
	has_steps "${_steps}" || rm -r "${_builddir}"

	return "${_err}"
}

# unpriv [-c class] user utility argument ...
# unpriv [-c class] user
#
# Run utility or stdin as the given user.
unpriv() (
	local _class=""
	local _user

	while [ $# -gt 0 ]; do
		case "$1" in
		-c)	shift; _class="$1";;
		*)	break;;
		esac
		shift
	done

	_user="$1"; : "${_user:?}"; shift

	# Since robsd is running as root, su(1) will preserve the following
	# environment variables which is unwanted by especially some regress
	# tests.
	LOGNAME="${_user}"
	USER="${_user}"
	if [ $# -gt 0 ]; then
		su ${_class:+-c "${_class}"} "${_user}" -c "$@"
	else
		su ${_class:+-c "${_class}"} "${_user}" -sx
	fi
)
