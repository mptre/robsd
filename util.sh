# Array indices for _STAGE array populated by stage_eval.
_STAGE_ID=0
_STAGE_NAME=1
_STAGE_EXIT=2
_STAGE_DURATION=3
_STAGE_LOG=4
_STAGE_TIME=5

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
	while read _file _path; do
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

# stage_eval stage file
#
# Read the given stage from file into the array _STAGE.
stage_eval() {
	local _stage="$1" _file="$2" _i=0 _k _next _s _v

	set -A _STAGE

	if [ $_stage -lt 0 ]; then
		_line="$(tail "$_stage" "$_file" | head -1)"
	else
		_line="$(sed -n -e "${_stage}p" "$_file")"
	fi
	[ -z "$_line" ] && return 1

	while :; do
		_next="${_line%% *}"
		_k="${_next%=*}"
		_v="${_next#*=\"}"; _v="${_v%\"}"

		case "$_k" in
		stage)		_STAGE[$_STAGE_ID]="$_v";;
		name)		_STAGE[$_STAGE_NAME]="$_v";;
		exit)		_STAGE[$_STAGE_EXIT]="$_v";;
		duration)	_STAGE[$_STAGE_DURATION]="$_v";;
		log)		_STAGE[$_STAGE_LOG]="$_v";;
		time)		_STAGE[$_STAGE_TIME]="$_v";;

		*)	echo "stage_eval: ${_file}: unknown field ${_k}" 1>&2
			return 1
			;;
		esac

		_next="${_line#* }"
		if [ "$_next" = "$_line" ]; then
			break
		else
			_line="$_next"
		fi
		_i=$((i + 1))
	done

	if [ ${#_STAGE[*]} -eq 0 ]; then
		return 1
	else
		return 0
	fi
}
