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

# diff_root diff
#
# Find the root directory for the given diff.
diff_root() {
	local _file _p _path

	grep -e '^Index:' -e '^RCS file:' "$1" |
	awk '{print $NF}' |
	sed -e 's/,v$//' -e 's,/src/,/usr/src/,g' |
	head -2 |
	xargs -r |
	while read -r _file _path; do
		_p="${_path%/${_file}}"
		while [ -n "$_p" ]; do
			[ -e "$_p" ] && break

			_p="$(path_strip "$_p")"
		done

		echo "$_p"
		return 0
	done
}

# duration_format duration
#
# Format the given duration to a human readable representation.
duration_format() {
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

	echo "$(stage_value duration)"
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
		duration_format "$_d"
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
		"$(duration_format "$_d")" \
		"$_sign" \
		"$(duration_format "$_delta")"
}

# report_recipients stages
#
# Writes the report recipients based on the given stages file.
# If the user that started the release is not in the wheel group, root will
# receive the report as well.
report_recipients() {
	local _user

	stage_eval 1 "$1"
	_user="$(stage_value user)"
	if ! groups "$_user" | grep -qw wheel; then
		printf 'root '
	fi
	echo "$_user"
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
	local _stage="$1" _file="$2" _i _k _next _v

	set -A _STAGE

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
