# build_duration stages
#
# Calculate the accumulated build duration.
build_duration() {
	local _i=1 _stages="$1" _tot=0 _d

	while stage_eval "$_i" "$_stages"; do
		_i=$((_i + 1))

		# Do not include the previous accumulated build duration.
		[ "${_STAGE[$(stage_field name)]}" = "end" ] && continue

		_d="${_STAGE[$(stage_field duration)]}"
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
		_h="$((_d / 3600))h"
		_d=$((_d % 3600))
	fi

	if [ "$_d" -ge 60 ]; then
		_m="$((_d / 60))m"
		_d=$((_d % 60))
	fi

	if [ "$_d" -gt 0 ]; then
		_s="${_d}s"
	fi

	echo $_h $_m $_s
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

# report_recipients stages
#
# Writes the report recipients based on the given stages file.
# If the user that started the release is not in the wheel group, root will
# receive the report as well.
report_recipients() {
	local _user

	stage_eval 1 "$1"
	_user="${_STAGE[$(stage_field user)]}"
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
# Writes the corresponding _STAGE array index for the given field name.
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
