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
