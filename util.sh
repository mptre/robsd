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

			_p="$(strip_path "$_p")"
		done

		echo "$_p"
		return 0
	done
}

# strip_path path
#
# Strip of the first component of the given path.
strip_path() {
	local _src="$1" _dst

	_dst="${_src#/}"
	[ "${_dst#*/}" = "$_dst" ] && return 0
	echo "/${_dst#*/}"

}
