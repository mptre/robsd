# diff_root diff
#
# Find the root directory for the given diff.
diff_root() {
	local _file _path

	grep -e '^Index:' -e '^RCS file:' "$1" |
	awk '{print $NF}' |
	sed -e 's/,v$//' -e 's,^/cvs,/usr,' |
	head -2 |
	xargs -r |
	while read _file _path; do
		_path="$(dirname "$_path")"
		while [ -n "$_path" ]; do
			if [ -e "${_path}/${_file}" ]; then
				echo "$_path"
				return 0
			fi
			_path="$(strip_path "$_path")"
		done
	done
}

# strip_path path
#
# Strip of the last component of the given path.
strip_path() {
	local _src="$1" _dst

	_dst="${_src%/*}"
	[ "$_src" = "$_dst" ] && return 0

	echo "$_dst"
}
