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
}

# cvs_field field log-line
#
# Extract the given field from a cvs log line.
cvs_field() {
	local _field _line

	_field="$1"; : "${_field:?}"
	_line="$2"; : "${_line:?}"

	_line="${_line##*${_field}: }"; _line="${_line%%;*}"
	echo "$_line"
}

# cvs_log -r cvs-dir -t tmp-dir -u user
#
# Generate a descending log of all commits since the last release build for the
# given repository. Individual revisions are group by commit id and sorted by
# date.
cvs_log() {
	local _indent="  "
	local _message=0
	local _date _id _line _log _path _prev _repo _user

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
	_prev="$(prev_release)"
	stage_eval -n cvs "${_prev}/stages"
	_log="$(stage_value log)"
	_date="$(grep -m 1 '^Date:' "$_log" | sed -e 's/^[^:]*: *//')"
	: "${_date:?}"
	_date="$(date -j -f '%Y/%m/%d %H:%M:%S' +'%F %T' "$_date")"

	grep '^[MPU]\>' |
	cut -d ' ' -f 2 |
	su "$_user" -c "cd ${_repo} && xargs cvs -q log -N -l -d '>${_date}'" |
	while read -r _line; do
		case "$_line" in
		Working\ file:*)
			_path="${_line#*: }"
			;;
		date:*)
			_date="$(cvs_field date "$_line")"
			_id="$(cvs_field commitid "$_line")"
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

# diff_clean dir
#
# Remove leftovers from cvs and patch in dir.
diff_clean() {
	find "$1" -type f \( \
		-name '*.orig' -o -name '*.rej' -o -name '.#*' \) -print0 |
	xargs -0rt rm
}

# diff_copy src dst
#
# Copy the given diff located at src to dst.
# Exits non-zero if dst already exists.
diff_copy() {
	local _src="$1" _dst="$2"

	if [ -e "$_dst" ]; then
		if [ -n "$_src" ] && ! cmp -s "$_src" "$_dst"; then
			return 1
		fi
	elif [ -n "$_src" ]; then
		cp "$_src" "$_dst"
		chmod 644 "$_dst"
	fi

	if [ -e "$_dst" ]; then
		echo "$_dst"
	fi
	return 0
}

# diff_root [-f fallback] -r repo diff
#
# Find the root directory for the given diff. Otherwise, use the given fallback.
diff_root() {
	local _file _p _path
	local _fallback="" _repo=""

	while [ $# -gt 0 ]; do
		case "$1" in
		-f)	shift; _fallback="$1";;
		-r)	shift; _repo="$1";;
		*)	break
		esac
		shift
	done
	: "${_repo:?}"

	grep -e '^Index:' -e '^RCS file:' "$1" |
	awk '{print $NF}' |
	sed -e 's/,v$//' -e "s,/.*/${_repo}/,/usr/${_repo}/," |
	head -2 |
	xargs -r |
	while read -r _file _path; do
		_p="${_path%/${_file}}"
		while [ -n "$_p" ]; do
			[ -e "$_p" ] && break

			_p="$(path_strip "$_p")"
		done

		echo "$_p"
		return 1
	done && echo "$_fallback"

	return 0
}

# duration_prev stage-name
#
# Get the duration for the given stage from the previous successful release.
# Exits non-zero if no previous release exists or the previous one failed.
duration_prev() {
	local _prev _stage

	_stage="$1"
	: "${_stage:?}"

	prev_release 8 |
	while read -r _prev; do
		stage_eval -n "$_stage" "${_prev}/stages" || continue

		stage_value duration
		return 1
	done || return 0

	return 1
}

# duration_total stages
#
# Calculate the accumulated build duration.
duration_total() {
	local _i=1
	local _tot=0
	local _d _stages

	_stages="$1"
	: "${_stages:?}"

	while stage_eval "$_i" "$_stages"; do
		_i=$((_i + 1))

		# Do not include the previous accumulated build duration.
		# Could be present if the report is re-generated.
		[ "$(stage_value name)" = "end" ] && continue

		_d="$(stage_value duration)"
		_tot=$((_tot + _d))
	done

	echo "$_tot"
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
# to 1.
prev_release() {
	find "$BUILDDIR" -type d -mindepth 1 -maxdepth 1 |
	sort -nr |
	grep -v -e "$LOGDIR" -e "${BUILDDIR}/attic" |
	head "-${1:-1}"
}

# purge dir count
#
# Keep the latest count number of release directories in dir.
# The older ones will be moved to the attic, keeping only the relevant files.
# All purged directories are written to stdout.
purge() {
	local _attic="${BUILDDIR}/attic" _dir="$1" _log="" _n="$2"
	local _d _dst

	find "$_dir" -type d -mindepth 1 -maxdepth 1 |
	grep -v "$_attic" |
	sort -n |
	tail -r |
	tail -n "+$((_n + 1))" |
	while read -r _d; do
		[ -d "$_attic" ] || mkdir "$_attic"

		# If the last stage failed, keep the log.
		if stage_eval -1 "${_d}/stages" 2>/dev/null &&
			[ "$(stage_value exit)" -ne 0 ]
		then
			_log="$(basename "$(stage_value log)")"
		fi

		find "$_d" -mindepth 1 -not \( \
			-name '*.diff' -o \
			-name '*cvs.log' -o \
			-name '*env.log' -o \
			-name 'comment' -o \
			-name 'index.txt' -o \
			-name 'report' -o \
			-name 'stages' -o \
			-name "$_log" \) -delete

		# Transform: YYYY-MM-DD.X -> YYYY/MM/DD.X
		_dst="${_attic}/$(echo "${_d##*/}" | tr '-' '/')"
		mkdir -p "${_dst%/*}"
		mv "$_d" "$_dst"
		echo "$_d"
	done
}

# reboot_commence
#
# Commence reboot and continue building the current release after boot.
reboot_commence() {
	# Do not inherit standard file descriptors in order to let the boot
	# process proceed.
	cat <<-EOF >>/etc/rc.firsttime
	(
	exec </dev/null >/dev/null 2>&1
	/usr/local/sbin/robsd -r ${LOGDIR} &
	)
	EOF

	# Add some grace in order to let the script finish.
	shutdown -r '+1' </dev/null >/dev/null 2>&1
}

# report [-M] -r report -s stages
#
# Create a build report and save it to report.
report() {
	local _duration=0
	local _i=1
	local _mail=1
	local _name=""
	local _f _log _report _stages _status

	while [ $# -gt 0 ]; do
		case "$1" in
		-M)	_mail=0;;
		-r)	shift; _report="$1";;
		-s)	shift; _stages="$1";;
		*)	break;;
		esac
		shift
	done

	# The stages file could be absent when a build fails to start due to
	# another already running build.
	[ -e "$_stages" ] || return 0

	# Clear or create report. Useful when resuming a build only to re-create
	# the report.
	echo -n >"$_report"

	# Add comment to the beginning of the report.
	if [ -e "${LOGDIR}/comment" ]; then
		cat <<-EOF >>"$_report"
		> comment:
		$(cat "${LOGDIR}/comment")

		EOF
	fi

	# Add stats to the beginning of the report.
	stage_eval -1 "$_stages"
	if [ "$(stage_value exit)" -eq 0 ]; then
		_status="ok"
		_duration="$(stage_value duration)"
		_duration="$(report_duration -d end -t 60 "$_duration")"
	else
		_status="failed in $(stage_value name)"
		_duration="$(duration_total "$_stages")"
		_duration="$(report_duration "$_duration")"
	fi
	{
		cat <<-EOF
		> stats:
		Status: ${_status}
		Duration: ${_duration}
		Build: ${LOGDIR}
		EOF

		report_sizes "$(release_dir "$LOGDIR")"
	} >>"$_report"

	while stage_eval "$_i" "$_stages"; do
		_i=$((_i + 1))

		_name="$(stage_value name)"
		_log="$(stage_value log)"
		report_skip "$_name" "$_log" && continue

		_duration="$(stage_value duration)"

		printf '\n> %s:\n' "$_name"
		printf 'Exit: %d\n' "$(stage_value exit)"
		printf 'Duration: %s\n' "$(report_duration -d "$_name" "$_duration")"
		printf 'Log: %s\n' "$(basename "$_log")"
		report_log "$_name" "$(stage_value log)"
	done >>"$_report"

	# Do not send mail during interactive invocations.
	{ [ -t 0 ] || [ "$_mail" -eq 0 ]; } && return 0

	mail -s "robsd: $(machine): ${_status}" root <"$_report"
}

# report_duration [-d stage] [-t threshold] duration
#
# Format the given duration to a human readable representation.
# If option `-d' is given, the duration delta for the given stage relative
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

# report_log stage log
#
# Writes an excerpt of the given log.
report_log() {
	[ -s "$2" ] && echo

	case "$1" in
	cvs|patch|checkflist|revert|distrib)
		cat "$2"
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

# report_skip stage-name [stage-log]
#
# Exits zero if the given stage should not be included in the report.
report_skip() {
	local _name _log

	_name="$1"; : "${_name:?}"

	case "$_name" in
	env|end)
		return 0
		;;
	checkflist)
		# Skip if the log only contains PS4 traces.
		_log="$2"
		grep -vq '^\+' "$_log" || return 0
		;;
	patch|revert)
		[ -z "$SRCDIFF" ] && [ -z "$X11DIFF" ] && return 0
		;;
	esac

	return 1
}

# release_dir prefix
#
# Writes the release directory with the given prefix applied.
release_dir() {
	echo "${1}/reldir"
}

# stage_eval offset file
# stage_eval -n stage-name file
#
# Read the given stage from file into the _STAGE array. The offset argument
# refers to a line in file. A negative offset starts from the end of file.
stage_eval() {
	local _name=0
	local _file _i _k _next _stage _v

	while [ $# -gt 0 ]; do
		case "$1" in
		-n)	_name=1;;
		*)	break;;
		esac
		shift
	done
	_stage="$1"
	: "${_stage:?}"
	_file="$2"
	: "${_file:?}"

	set -A _STAGE

	if ! [ -e "$_file" ]; then
		echo "stage_eval: ${_file}: no such file" 1>&2
		return 1
	fi

	if [ "$_name" -eq 1 ]; then
		_line="$(sed -n -e "/name=\"${_stage}\"/p" "$_file")"
	elif [ "$_stage" -lt 0 ]; then
		_line="$(tail "$_stage" "$_file" | head -1)"
	else
		_line="$(sed -n -e "${_stage}p" "$_file")"
	fi
	[ -z "$_line" ] && return 1

	while :; do
		_next="${_line%% *}"
		_k="${_next%=*}"
		_v="${_next#*=\"}"; _v="${_v%\"}"

		_i="$(stage_field "$_k")"
		if [ "$_i" -lt 0 ]; then
			echo "stage_eval: ${_file}: unknown field ${_k}" 1>&2
			return 1
		fi
		_STAGE[$_i]="$_v"

		_next="${_line#* }"
		if [ "$_next" = "$_line" ]; then
			break
		else
			_line="$_next"
		fi
	done

	if [ ${#_STAGE[*]} -eq 0 ]; then
		return 1
	else
		return 0
	fi
}

# stage_field name
#
# Get the corresponding _STAGE array index for the given field name.
stage_field() {
	case "$1" in
	stage)		echo 0;;
	name)		echo 1;;
	exit)		echo 2;;
	duration)	echo 3;;
	log)		echo 4;;
	time)		echo 5;;
	user)		echo 6;;
	*)		echo -1;;
	esac
}

# stage_value name
#
# Get corresponding value for the given field name in the global _STAGE array.
stage_value() {
	local _i

	_i="$(stage_field "$1")"

	echo "${_STAGE[$_i]}"
}

# stage_next stages
#
# Get the next stage to execute. If the last stage failed, it will be executed
# again. The exception also applies to the end stage, this is useful since it
# allows the report to be regenerated for a finished release.
stage_next() {
	local _stage

	stage_eval -1 "$1"
	_stage="$(stage_value stage)"
	if [ "$(stage_value exit)" -ne 0 ]; then
		echo "$_stage"
	elif [ "$(stage_value name)" = "end" ]; then
		echo "$_stage"
	else
		echo $((_stage + 1))
	fi
}
