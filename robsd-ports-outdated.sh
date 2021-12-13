. "${EXECDIR}/util.sh"

set -o pipefail

chroot "$CHROOT" sh -ex <<'EOF' | tsort -r >"${BUILDDIR}/tmp/outdated"
# outdated port
outdated() {
	local _port
	local _pkgfile

	set -x

	_port="$1"; : "${_port:?}"

	_pkgfile="$(env "SUBDIR=${_port}" make show=PKGFILE | grep -v '^===> ')"
	[ -e "$_pkgfile" ] || return 0

	_s1=$(pkg_info -S -Dunsigned $_pkgfile 2>&1 | sed -n -e 's/Signature: //p')
	_s2="$(env "SUBDIR=${_port}" make print-update-signature | grep -v '^===> ')"
	[ "$_s1" != "$_s2" ]
}

# printgraph port ...
printgraph() {
	local _a
	local _prev

	_prev="$1"; shift
	for _a; do
		echo "${_prev} ${_a}"
		_prev="$_a"
	done
}

# walk
walk()
{
	local _input="/tmp/walk"
	local _path="/tmp/path"
	local _port

	set -x

	cat >"$_input"
	while [ -s "$_input" ]; do
		read -r _port _ <"$_input"
		walk1 -i "$_input" -p "$_path" "$_port"
	done
	rm "$_input" "$_path"
}

# walk1 -i input -p path port
walk1()
{
	local _base
	local _dependency
	local _input
	local _path
	local _port

	set -x

	while [ $# -gt 0 ]; do
		case "$1" in
		-i)	shift; _input="$1";;
		-p)	shift; _path="$1";;
		*)	break;;
		esac
		shift
	done
	: "${_input:?}"
	: "${_path:?}"
	_port="$1"; : "${_port:?}"

	# Discard multi packages and always build everything. Not sure if this a
	# good idea.
	_base="${_port%,-*}"
	echo "$_base" >>"$_path"

	if grep -q "$_base" "$_checked"; then
		# Dependency already flagged as up-to-date.
		:
	elif grep -q "$_base" "$_outdated"; then
		# Dependency already flagged as outdated, implies that
		# the port is also outdated.
		printgraph $(<"$_path")
	elif outdated "$_base"; then
		# Dependency outdated, implies that the port is also
		# outdated.
		echo "$_base" >>"$_outdated"
		printgraph $(<"$_path")
	else
		# Dependency up-to-date, take note.
		echo "$_base" >>"$_checked"
	fi

	while [ "$(head -1 "$_input" | cut -d ' ' -f 1)" = "$_port" ]; do
		read -r _ _dependency <"$_input"
		sed -i -e '1d' "$_input"
		walk1 -i "$_input" -p "$_path" "$_dependency"
	done

	sed -i -e '$d' "$_path" || echo nein!
}

cd $PORTSDIR

_DEPENDS_CACHE=$(make create_DEPENDS_CACHE); export _DEPENDS_CACHE

_checked="/tmp/checked"; : >"$_checked"
_depends="/tmp/depends"; : >"$_depends"
_outdated="/tmp/outdated"; : >"$_outdated"
_tsort="/tmp/tsort"; : >"$_tsort"

env "SUBDIR=${PORTS}" make all-dir-depends |
tee "$_depends" |
walk |
tee "$_tsort"

make destroy_DEPENDS_CACHE
EOF
