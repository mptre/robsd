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

# build_duration stages
#
# Calculate the accumulated build duration.
build_duration() {
	local _i=1 _stages="$1" _tot=0 _d

	while stage_eval "$_i" "$_stages"; do
		_i=$((_i + 1))

		# Do not include the previous accumulated build duration.
		[ "$(stage_value name)" = "end" ] && continue

		_d="$(stage_value duration)"
		_tot=$((_tot + _d))
	done

	echo "$_tot"
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

# diff_copy src dst
#
# Copy the given diff located at src to dst.
# Exits non-zero if dst already exists.
diff_copy() {
	local _src="$1" _dst="$2"

	if [ -e "$_dst" ]; then
		[ -n "$_src" ] && return 1
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

# duration_prev
#
# Get the duration of the previous release.
# Exits non-zero if no previous release exists or the previous one failed.
duration_prev() {
	local _prev

	_prev="$(prev_release)"
	[ -z "$_prev" ] && return 1

	stage_eval -1 "${_prev}/stages"
	[ "$(stage_value name)" = "end" ] || return 1

	stage_value duration
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

# prev_release
#
# Get the previous release directory.
prev_release() {
	find "$BUILDDIR" -type d -mindepth 1 -maxdepth 1 |
	sort -n |
	grep -B 1 -e "$LOGDIR" |
	head -1
}

# purge dir count
#
# Keep the latest count number of release directories in dir.
# The older ones will be moved to the attic, keeping only the relevant files.
purge() {
	local _attic="${BUILDDIR}/attic" _dir="$1" _log="" _n="$2"
	local _d

	find "$_dir" -type d -mindepth 1 -maxdepth 1 |
	grep -v "$_attic" |
	sort -n |
	tail -r |
	tail -n "+$((_n + 1))" |
	while read -r _d; do
		info "moving ${_d} to the attic"

		[ -d "$_attic" ] || mkdir "$_attic"

		# If the last stage failed, keep the log.
		if stage_eval -1 "${_d}/stages" 2>/dev/null &&
			[ "$(stage_value exit)" -ne 0 ]
		then
			_log="$(basename "$(stage_value log)")"
		fi

		find "$_d" -mindepth 1 -not \( \
			-name stages -o -name report -o -name '*cvs.log' -o \
			-name '*.diff' -o -name "$_log" \) -delete

		mv "$_d" "$_attic"
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

# report_duration [-d] duration
#
# Format the given duration to a human readable representation.
# If option `-d' is given, the duration delta for previous release is also
# formatted.
report_duration() {
	local _do_delta=0
	local _d _delta _prev _sign

	while [ $# -gt 0 ]; do
		case "$1" in
		-d)	_do_delta=1;;
		*)	break;;
		esac
		shift
	done
	_d="$1"

	if [ "$_do_delta" -eq 0 ] || ! _prev="$(duration_prev)"; then
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
	printf '%s (%s%s)\n' \
		"$(format_duration "$_d")" \
		"$_sign" \
		"$(format_duration "$_delta")"
}

# report_size file
#
# Writes a human readable representation of the size of the given file.
# If the same file is present in the previous release, report that size as
# well.
report_size() {
	local _f="$1"
	local _delta _name _path _prev _s1 _s2

	: "${_f:?}"

	_name="$(basename "$_f")"

	printf '%s' "$_name"
	if ! [ -e "$_f" ]; then
		printf ' 0\n'
		return 0
	fi

	_s1="$(ls -l "$_f" | awk '{print $5}')"
	printf ' %s' "$(format_size "${_s1}")"

	_prev="$(prev_release)"
	if [ -n "$_prev" ]; then
		_path="$(release_dir "$_prev")/${_name}"
		if [ -e "$_path" ]; then
			_s2="$(ls -l "$_path" | awk '{print $5}')"
			_delta="$((_s1 - _s2))"
			if [ "$(abs "$_delta")" -ge $((1024 * 100)) ]; then
				printf ' (%s)' "$(format_size -M -s "$_delta")"
			fi
		fi
	fi

	printf '\n'
}

# report_skip stage
#
# Exits zero if the given stage should not be included in the report.
report_skip() {
	case "$1" in
	env|end)
		return 0
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

# stage_eval stage file
#
# Read the given stage from file into the array _STAGE.
stage_eval() {
	local _stage="$1" _file="$2"
	local _i _k _next _v

	set -A _STAGE

	if ! [ -e "$_file" ]; then
		echo "stage_eval: ${_file}: no such file" 1>&2
		return 1
	fi

	if [ "$_stage" -lt 0 ]; then
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
