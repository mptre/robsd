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

cd $PORTSDIR

_DEPENDS_CACHE=$(make create_DEPENDS_CACHE); export _DEPENDS_CACHE

_checked="/tmp/checked"; : >"$_checked"
_outdated="/tmp/outdated"; : >"$_outdated"
_tsort="/tmp/tsort"; : >"$_tsort"
for _p in $PORTS; do
	{
		env "SUBDIR=${_p}" make all-dir-depends
		echo "${_p} ${_p}"
	} | while read -r _parent _dependency; do
		if grep -q "$_dependency" "$_checked"; then
			# Dependency already flagged as up-to-date.
			:
		elif grep -q "$_dependency" "$_outdated"; then
			# Dependency already flagged as outdated, implies that
			# the port is also outdated.
			echo "${_parent} ${_dependency}"
		elif outdated "$_dependency"; then
			# Dependency outdated, implies that the port is also
			# outdated.
			echo "$_dependency" >>"$_outdated"
			echo "${_parent} ${_dependency}"
		else
			# Dependency up-to-date, take note.
			echo "$_dependency" >>"$_checked"
		fi
	done
done | tee "$_tsort"

make destroy_DEPENDS_CACHE
EOF
