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

_outdated="/tmp/outdated"; : >"$_outdated"
_checked="/tmp/checked"; : >"$_checked"
for _p in $PORTS; do
	env "SUBDIR=${_p}" make all-dir-depends |
	tsort -r |
	while read -r _d
	do
		if grep -q "$_d" "$_checked"; then
			# Dependency already flagged as up-to-date.
			:
		elif grep -q "$_d" "$_outdated"; then
			# Dependency already flagged as outdated, the port and
			# all of its dependencies are therefore considered
			# outdated.
			echo "${_p} ${_d}"
		elif outdated "$_d"; then
			# Dependency outdated, the port and all of its
			# dependencies are therefore considered outdated.
			echo "$_d" >>"$_outdated"
			echo "${_p} ${_d}"
		else
			# Dependency up-to-date, take note.
			echo "$_d" >>"$_checked"
		fi
	done
done

make destroy_DEPENDS_CACHE
EOF
