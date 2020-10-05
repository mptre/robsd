# abs number
#
# Get the absolute value of the given number.
abs() {
	local _n="$1"

	: "${_n:?}"

	if [ "$_n" -lt 0 ]; then
		echo "$((- _n))"
	else
		echo "$_n"
	fi
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

# comment src dst
#
# Copy the comment file src to dst. If src is `-', stdin is used.
# Exits non-zero if dst already exists.
comment() {
	local _dst _src

	_src="$1"; : "${_src:?}"
	_dst="$2"; : "${_dst:?}"

	[ -e "$_dst" ] && return 1

	if [ "$_src" = "-" ]; then
		cat >"$_dst"
	else
		cp "$_src" "$_dst"
	fi
	if ! [ -s "$_dst" ]; then
		rm "$_dst"
	fi
}

# config_load path
#
# Load and validate the configuration.
config_load() {
	local _diff
	local _path
	local _tmp

	_path="$1"; : "${_path:?}"

	# Global variables with sensible defaults.
	export BSDDIFF; : "${BSDDIFF:=}"
	export BSDOBJDIR; : "${BSDOBJDIR:="/usr/obj"}"
	export BSDSRCDIR; : "${BSDSRCDIR:="/usr/src"}"
	export BUILDDIR
	export CVSROOT
	export CVSUSER
	export DESTDIR
	export DETACH; : "${DETACH:=0}"
	export DISTRIBHOST; : "${DISTRIBHOST:=}"
	export DISTRIBPATH; : "${DISTRIBPATH:=}"
	export DISTRIBUSER; : "${DISTRIBUSER:=}"
	export EXECDIR; : "${EXECDIR:="/usr/local/libexec/robsd"}"
	export HOOK; : "${HOOK:=}"
	export KEEP; : "${KEEP:=0}"
	export LOGDIR
	export MAKEFLAGS; : "${MAKEFLAGS:="-j$(sysctl -n hw.ncpuonline)"}"
	export PATH; PATH="${PATH}:/usr/X11R6/bin"
	export SIGNIFY; : "${SIGNIFY:=}"
	export SKIP; : "${SKIP:=}"
	export XDIFF; : "${XDIFF:=}"
	export XOBJDIR; : "${XOBJDIR="/usr/xobj"}"
	export XSRCDIR; : "${XSRCDIR="/usr/xenocara"}"

	. "$_path"

	# Ensure mandatory variables are defined.
	: "${BUILDDIR:?}"
	: "${CVSROOT:?}"
	: "${CVSUSER:?}"
	: "${DESTDIR:?}"
	: "${XOBJDIR:?}"

	# Filter out missing source diff(s).
	_tmp=""
	for _diff in $BSDDIFF; do
		[ -e "$_diff" ] || continue

		_tmp="${_tmp}${_tmp:+ }${_diff}"
	done
	BSDDIFF="$_tmp"

	# Filter out xenocara diff(s).
	_tmp=""
	for _diff in $XDIFF; do
		[ -e "$_diff" ] || continue

		_tmp="${_tmp}${_tmp:+ }${_diff}"
	done
	XDIFF="$_tmp"
}

# cvs_field field log-line
#
# Extract the given field from a cvs log line.
cvs_field() {
	local _field _line

	_field="$1"; : "${_field:?}"
	_line="$2"; : "${_line:?}"

	echo "$_line" | grep -q -F "$_field" || return 1

	_line="${_line##*${_field}: }"; _line="${_line%%;*}"
	echo "$_line"
}

# cvs_log -r cvs-dir -t tmp-dir -u user
#
# Generate a descending log of all commits since the last release build for the
# given repository. Individual revisions are group by commit id and sorted by
# date.
cvs_log() {
	local _date=""
	local _indent="  "
	local _message=0
	local _id _line _log _path _prev _repo _user

	while [ $# -gt 0 ]; do
		case "$1" in
		-r)	shift; _repo="$1";;
		-t)	shift; _tmp="$1";;
		-u)	shift; _user="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_repo:?}"
	: "${_tmp:?}"
	: "${_user:?}"

	# Use the date from latest revision from the previous release.
	for _prev in $(prev_release 0); do
		# Find cvs date threshold. By default, try to use the date from
		# the last revision from the previous release. Otherwise if the
		# previous release didn't include any new revisions, use the
		# execution date of the cvs step from the previous release.
		step_eval -n cvs "${_prev}/steps"

		step_skip && continue

		if ! _log="$(step_value log 2>/dev/null)"; then
			continue
		fi
		_date="$(grep -m 1 '^Date:' "$_log" | sed -e 's/^[^:]*: *//')"
		if [ -n "$_date" ]; then
			_date="$(date -j -f '%Y/%m/%d %H:%M:%S' +'%F %T' "$_date")"
		else
			if ! _date="$(step_value time 2>/dev/null)"; then
				continue
			fi
			_date="$(date -r "$_date" '+%F %T')"
		fi
		[ -n "$_date" ] && break
	done
	if [ -z "$_date" ]; then
		echo "cvs_log: previous date not found" 1>&2
		return 0
	fi

	grep '^[MPU]\>' |
	cut -d ' ' -f 2 |
	su "$_user" -c "cd ${_repo} && xargs cvs -q log -N -l -d '>${_date}'" |
	tee "${_tmp}/cvs-log" |
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

# diff_apply -u user diff
#
# Apply the given diff, operating as user.
diff_apply() {
	local _diff=""
	local _user=""

	while [ $# -gt 0 ]; do
		case "$1" in
		-u)	shift; _user="$1";;
		*)	break;;
		esac
		shift
	done
	_diff="$1"
	: "${_user:?}"
	: "${_diff:?}"

	# Try to revert the diff if dry run fails.
	if ! su "$_user" -c "exec patch -Cfs" <"$_diff" >/dev/null; then
		su "$_user" -c "exec patch -Rs" <"$_diff"
	fi
	su "$_user" -c "exec patch -Es" <"$_diff"
}

# diff_clean dir
#
# Remove leftovers from cvs and patch in dir.
diff_clean() {
	find "$1" -type f \( \
		-name '*.orig' -o -name '*.rej' -o -name '.#*' \) -print0 |
	xargs -0rt rm 2>&1 |
	while read -r _cmd; do
		info "$_cmd"
	done
}

# diff_copy dst [src ...]
#
# Copy the given diff(s) located at src to dst.
diff_copy() {
	local _i=1
	local _base _dst _src

	[ "$#" -eq 1 ] && return 0

	_base="$1"; shift
	for _src; do
		_dst="${_base}.${_i}"

		cp "$_src" "$_dst"
		chmod 644 "$_dst"

		# Try hard to output everything on a single line.
		[ "$_i" -gt 1 ] && printf ' '
		echo -n "$_dst"

		_i=$((_i + 1))
	done
	printf '\n'

	return 0
}

# diff_list dir prefix
#
# List all diff in the given dir matching prefix.
diff_list() {
	local _dir _prefix

	_dir="$1" ; : "${_dir:?}"
	_prefix="$2" ; : "${_prefix:?}"
	find "$_dir" \( -type f -name "${_prefix}.*" \) -print0 | xargs -0
}

# diff_revert dir diff ...
#
# Revert the given diff(s).
diff_revert() {
	local _diff
	local _dir
	local _revert=0
	local _root

	_dir="$1"; : "${_dir:?}"; shift
	for _diff; do
		_root="$(diff_root -d "${_dir}" "$_diff")"
		cd "$_root"
		if su "$CVSUSER" -c "exec patch -CRfs" \
			<"$_diff" >/dev/null 2>&1
		then
			info "reverting diff ${_diff}"
			su "$CVSUSER" -c "exec patch -ERs" <"$_diff"
			_revert=1
		else
			info "diff already reverted ${_diff}"
		fi
	done
	if [ "$_revert" -eq 1 ]; then
		diff_clean "$_dir"
	fi
}

# diff_root -d directory diff
#
# Find the root directory for the given diff. Otherwise, use the given directory
# as a fallback.
diff_root() {
	local _file _p _path
	local _err=1
	local _root=""

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
		_p="${_path%/${_file}}"
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

# duration_prev step-name
#
# Get the duration for the given step from the previous successful release.
# Exits non-zero if no previous release exists or the previous one failed.
duration_prev() {
	local _prev
	local _step
	local _v

	_step="$1"
	: "${_step:?}"

	prev_release 0 |
	while read -r _prev; do
		step_eval -n "$_step" "${_prev}/steps" || continue

		_v="$(step_value duration 2>/dev/null)" || continue
		echo "$_v"
		return 1
	done || return 0

	return 1
}

# duration_total steps
#
# Calculate the accumulated build duration.
duration_total() {
	local _i=1
	local _tot=0
	local _d _steps

	_steps="$1"
	: "${_steps:?}"

	while step_eval "$_i" "$_steps"; do
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
	local _d="$1" _h="" _m="" _s=""

	[ "$_d" -eq 0 ] && { echo 0; return 0; }

	if [ "$_d" -ge 3600 ]; then
		_h="$((_d / 3600))"
		_d=$((_d % 3600))
	fi

	if [ "$_d" -ge 60 ]; then
		_m="$((_d / 60))"
		_d=$((_d % 60))
	fi

	if [ "$_d" -gt 0 ]; then
		_s="$_d"
	fi

	printf '%02d:%02d:%02d\n' "$_h" "$_m" "$_s"
}

# format_size [-M] [-s] size
#
# Format the given size into a human readable representation.
# Optionally include the sign if the size is a delta.
format_size() {
	local _d=1 _mega=0 _p="" _sign=0
	local _abs _size

	while [ $# -gt 0 ]; do
		case "$1" in
		-M)	_mega=1;;
		-s)	_sign=1;;
		*)	break;;
		esac
		shift
	done
	_size="$1"
	: "${_size:?}"

	_abs="$(abs "$_size")"
	if [ "$_mega" -eq 1 ] || [ "$_abs" -ge "$((1024 * 1024))" ]; then
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

	if [ "$DETACH" -eq 1 ]; then
		# Not fully detached yet, write all entries to robsd.log.
		_log="${LOGDIR}/robsd.log"
	fi
	echo "${_PROG}: ${*}" | tee -a "$_log"
}

# log_id -l log-dir -n step-name -s step-id
#
# Generate the corresponding log file name for the given step.
log_id() {
	local _id
	local _name=""
	local _logdir=""
	local _step=""

	while [ $# -gt 0 ]; do
		case "$1" in
		-l)	shift; _logdir="$1";;
		-n)	shift; _name="$1";;
		-s)	shift; _step="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_name:?}"
	: "${_logdir:?}"
	: "${_step:?}"

	_id="$(printf '%02d-%s.log' "$_step" "$_name")"
	_dups="$(find "$_logdir" -name "${_id}*" | wc -l)"
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
	local _src="$1" _dst

	_dst="${_src#/}"
	[ "${_dst#*/}" = "$_dst" ] && return 0
	echo "/${_dst#*/}"

}

# prev_release [count]
#
# Get the previous count number of release directories. Where count defaults
# to 1. If count is 0 means all previous release directories.
prev_release() {
	local _count

	_count="${1:-1}"

	find "$BUILDDIR" -type d -mindepth 1 -maxdepth 1 |
	sort -nr |
	grep -v -e "$LOGDIR" -e "${BUILDDIR}/attic" |
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
# The older ones will be moved to the attic, keeping only the relevant files.
# All purged directories are written to stdout.
purge() {
	local _attic="${BUILDDIR}/attic"
	local _dir="$1"
	local _n="$2"
	local _d _dst _tim

	find "$_dir" -type d -mindepth 1 -maxdepth 1 |
	grep -v "$_attic" |
	sort -n |
	tail -r |
	tail -n "+$((_n + 1))" |
	while read -r _d; do
		[ -d "$_attic" ] || mkdir "$_attic"

		# Grab the modification time before removal of irrelevant files.
		_tim="$(stat -f '%Sm' -t '%FT%T' "$_d")"

		find "$_d" -mindepth 1 -not \( \
			-name '*.diff.*' -o \
			-name '*cvs.log' -o \
			-name '*env.log' -o \
			-name 'comment' -o \
			-name 'index.txt' -o \
			-name 'report' -o \
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

# reboot_commence
#
# Commence reboot and continue building the current release after boot.
reboot_commence() {
	cat <<-EOF >>/etc/rc.firsttime
	/usr/local/sbin/robsd -D -r ${LOGDIR} >/dev/null
	EOF

	# Add some grace in order to let the script finish.
	shutdown -r '+1' </dev/null >/dev/null 2>&1
}

# report -r report -s steps
#
# Create a build report and save it to report.
report() {
	local _duration=0
	local _i
	local _name=""
	local _exit _f _log _report _steps _status _tmp

	while [ $# -gt 0 ]; do
		case "$1" in
		-r)	shift; _report="$1";;
		-s)	shift; _steps="$1";;
		*)	break;;
		esac
		shift
	done

	# The steps file could be absent when a build fails to start due to
	# another already running build.
	[ -e "$_steps" ] || return 1

	_tmp="$(mktemp -t robsd.XXXXXX)"


	# The last none skipped step determines success or failure.
	_i=1
	while step_eval "-${_i}" "$_steps"; do
		_i=$((_i + 1))

		step_skip && continue

		if [ "$(step_value exit)" -eq 0 ]; then
			_status="ok"
			_duration="$(step_value duration)"
			_duration="$(report_duration -d end -t 60 "$_duration")"
		else
			_status="failed in $(step_value name)"
			_duration="$(duration_total "$_steps")"
			_duration="$(report_duration "$_duration")"
		fi
		break
	done

	# Add headers.
	cat <<-EOF >"$_tmp"
	Subject: robsd: $(machine): ${_status}

	EOF

	# Add comment to the beginning of the report.
	if [ -e "${LOGDIR}/comment" ]; then
		cat <<-EOF >>"$_tmp"
		> comment:
		$(cat "${LOGDIR}/comment")

		EOF
	fi

	# Add stats to the beginning of the report.
	{
		cat <<-EOF
		> stats:
		Status: ${_status}
		Duration: ${_duration}
		Build: ${LOGDIR}
		EOF

		report_sizes "$(release_dir "$LOGDIR")"
	} >>"$_tmp"

	_i=1
	while step_eval "$_i" "$_steps"; do
		_i=$((_i + 1))

		step_skip && continue

		_name="$(step_value name)"
		_exit="$(step_value exit)"
		_log="$(step_value log)"
		[ "$_exit" -eq 0 ] && report_skip "$_name" "$_log" && continue

		_duration="$(step_value duration)"

		printf '\n> %s:\n' "$_name"
		printf 'Exit: %d\n' "$_exit"
		printf 'Duration: %s\n' "$(report_duration -d "$_name" "$_duration")"
		printf 'Log: %s\n' "$(basename "$_log")"
		report_log "$_name" "$(step_value log)"
	done >>"$_tmp"

	# smtpd(8) rejects messages with carriage return not followed by a
	# newline. Play it safe and let vis(1) encode potential carriage
	# returns.
	vis "$_tmp" >"$_report"
	rm "$_tmp"
}

# report_duration [-d steps] [-t threshold] duration
#
# Format the given duration to a human readable representation.
# If option `-d' is given, the duration delta for the given step relative
# to the previous succesful release is also formatted if the delta is greater
# than the given threshold.
report_duration() {
	local _delta=""
	local _threshold=0
	local _d _prev _sign

	while [ $# -gt 0 ]; do
		case "$1" in
		-d)	shift; _delta="$1";;
		-t)	shift; _threshold="$1";;
		*)	break;;
		esac
		shift
	done
	_d="$1"

	if [ -z "$_delta" ] || ! _prev="$(duration_prev "$_delta")"; then
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

# report_log step log
#
# Writes an excerpt of the given log.
report_log() {
	[ -s "$2" ] && echo

	case "$1" in
	env|cvs|patch|checkflist|reboot|revert|distrib)
		cat "$2"
		;;
	kernel)
		tail -n 11 "$2"
		;;
	*)
		tail "$2"
		;;
	esac
}

# report_size file
#
# If the given file is significantly larger than the same file in the previous
# release, a human readable representation of the size and delta is reported.
report_size() {
	local _f="$1"
	local _delta _name _path _prev _s1 _s2

	: "${_f:?}"

	_name="$(basename "$_f")"

	[ -e "$_f" ] || return 0

	_prev="$(prev_release)"
	[ -z "$_prev" ] && return 0

	_path="$(release_dir "$_prev")/${_name}"
	[ -e "$_path" ] || return 0

	_s1="$(ls -l "$_f" | awk '{print $5}')"
	_s2="$(ls -l "$_path" | awk '{print $5}')"
	_delta="$((_s1 - _s2))"
	[ "$(abs "$_delta")" -ge $((1024 * 100)) ] || return 0

	echo "$_name" "$(format_size "$_s1")" \
		"($(format_size -M -s "$_delta"))"
}

# report_sizes release_dir
#
# Report significant growth of any file present in the given release directory.
report_sizes() {
	local _dir="$1"
	local _f _siz

	: "${_dir:?}"

	[ -d "$_dir" ] || return 0

	find "$_dir" -type f | while read -r _f; do
		_siz="$(report_size "$_f")"
		[ -z "$_siz" ] && continue

		echo "Size: ${_siz}"
	done
}

# report_skip step-name [step-log]
#
# Exits zero if the given step should not be included in the report.
report_skip() {
	local _name _log

	_name="$1"; : "${_name:?}"

	case "$_name" in
	env|end|reboot)
		return 0
		;;
	checkflist)
		# Skip if the log only contains PS4 traces.
		_log="$2"
		grep -vq '^\+' "$_log" || return 0
		;;
	patch|revert)
		[ -z "$BSDDIFF" ] && [ -z "$XDIFF" ] && return 0
		;;
	*)	;;
	esac

	return 1
}

# release_dir [-x] prefix
#
# Get the release directory with the given prefix applied.
release_dir() {
	local _suffix

	if [ "$#" -eq 2 ] && [ "$1" = "-x" ]; then
		shift
		_suffix="relx"
	else
		_suffix="rel"
	fi
	echo "${1}/${_suffix}"
}

# setprogname name
#
# Set the name of the program to be used during logging.
setprogname() {
	_PROG="$1"; export _PROG
}

# step_end [-S] [-d duration] [-e exit] [-l log] -n name -s step-id file
#
# Mark the given step as ended by writing an entry to the given file.
step_end() {
	local _d=-1
	local _e=0
	local _l=""
	local _n
	local _s
	local _skip=""

	while [ $# -gt 0 ]; do
		case "$1" in
		-d)	shift; _d="$1";;
		-e)	shift; _e="$1";;
		-l)	shift; _l="$1";;
		-n)	shift; _n="$1";;
		-S)	_skip="1";;
		-s)	shift; _s="$1";;
		*)	break;;
		esac
		shift
	done

	# Remove any existing entry for the same step, could be present if a
	# previous execution failed.
	[ -e "$1" ] && sed -i -e "/step=\"${_s}\"/d" "$1"

	# Caution: all values must be quoted and cannot contain spaces.
	{
		printf 'step="%d"\n' "$_s"
		printf 'name="%s"\n' "$_n"

		if [ "$_skip" -eq 1 ]; then
			printf 'skip="1"\n'
		else
			printf 'exit="%d"\n' "$_e"
			printf 'duration="%d"\n' "$_d"
			printf 'log="%s"\n' "$_l"
			printf 'user="%s"\n' "$(logname)"
			printf 'time="%d"\n' "$(date '+%s')"
		fi
	} | paste -s -d ' ' - >>"$1"

	# Sort steps as skipped steps are added at the begining.
	mv "$1" "${1}.orig"
	sort -V "${1}.orig" >"$1"
	rm "${1}.orig"

	# Only invoke the hook if the step has ended. A duration of -1 is a
	# sentinel value indicating that the step has just begun.
	if [ "$_d" -ne -1 ] && [ -n "$HOOK" ]; then
		info "running hook ${HOOK}"
		"$HOOK" "$LOGDIR" "$_n" "$_e"
	fi
}

# step_eval offset file
# step_eval -n step-name file
#
# Read the given step from file into the _STEP array. The offset argument
# refers to a line in file. A negative offset starts from the end of file.
step_eval() {
	local _file _i _k _next _step _v
	local _n
	local _name=0

	while [ $# -gt 0 ]; do
		case "$1" in
		-n)	_name=1;;
		*)	break;;
		esac
		shift
	done
	_step="$1"
	: "${_step:?}"
	_file="$2"
	: "${_file:?}"

	set -A _STEP

	if ! [ -e "$_file" ]; then
		echo "step_eval: ${_file}: no such file" 1>&2
		return 1
	fi

	if [ "$_name" -eq 1 ]; then
		_line="$(sed -n -e "/name=\"${_step}\"/p" "$_file")"
	elif [ "$_step" -lt 0 ]; then
		_n="$(wc -l "$_file" | awk '{print $1}')"
		[ $((- _step)) -gt "$_n" ] && return 1
		_line="$(tail "$_step" "$_file" | head -1)"
	else
		_line="$(sed -n -e "${_step}p" "$_file")"
	fi
	[ -z "$_line" ] && return 1

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

# step_field name
#
# Get the corresponding _STEP array index for the given field name.
step_field() {
	case "$1" in
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
	_id="$(step_names | cat -n | grep -w "$_name" | awk '{print $1}')"
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

	_step="$(step_names | sed -n -e "${1}p")"
	if [ -n "$_step" ]; then
		echo "$_step"
	else
		return 1
	fi
}

# step_names
#
# Writes the names of all steps in execution order.
# The last step named end is a sentinel step without a corresponding step
# script.
step_names() {
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
}

# step_next steps
#
# Get the next step to execute. If the last step failed, it will be executed
# again. The exception also applies to the end step, this is useful since it
# allows the report to be regenerated for a finished release.
step_next() {
	local _i=1
	local _step

	while step_eval "-${_i}" "$1"; do
		_i="$((_i + 1))"

		# The skip field is optional, suppress errors.
		if [ "$(step_value skip 2>/dev/null)" -eq 1 ]; then
			continue
		fi

		_step="$(step_value step)"
		if [ "$(step_value exit)" -ne 0 ]; then
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

# step_value name
#
# Get corresponding value for the given field name in the global _STEP array.
step_value() {
	local _i

	_i="$(step_field "$1")"
	if [ "$_i" -lt 0 ] || ! echo "${_STEP[$_i]}" >/dev/null 2>&1; then
		echo "step_value: ${1}: unknown field" 1>&2
		return 1
	fi
	echo "${_STEP[$_i]}"
}
