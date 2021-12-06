robsd_mock >"$TMP1"; read -r WRKDIR BINDIR ROBSDDIR <"$TMP1"

# Sentinel file used to represent an up-to-date package.
: >"${WRKDIR}/pkgfile"

# Default configuration.
cat <<EOF >"${WRKDIR}/robsd-ports.conf"
ROBSDDIR=${ROBSDDIR}
EXECDIR=${EXECDIR}
CHROOT=/var/empty
PORTSDIR=/var/empty
PORTSUSER=nobody
EOF

cat <<'EOF' >"${BINDIR}/chroot"
#!/bin/sh

shift 1
exec "$@"
EOF
chmod u+x "${BINDIR}/chroot"

cat <<'EOF' >"${BINDIR}/make"
#!/bin/sh

# robsd-ports-outdated.sh
_outdated=1
if [ "$1" = "create_DEPENDS_CACHE" ]; then
	:
elif [ "$1" = "destroy_DEPENDS_CACHE" ]; then
	:
elif [ "$1" = "all-dir-depends" ]; then
	case "$SUBDIR" in
	*)
		echo "${SUBDIR} ${SUBDIR}"
		;;
	esac
elif [ "$1" = "print-update-signature" ]; then
	case "$SUBDIR" in
	devel/updated)	echo "signature ok";;
	*)		echo "signature outdated";;
	esac
elif [ "$1" = "show=PKGFILE" ]; then
	case "$SUBDIR" in
	devel/updated)	echo "${WRKDIR}/pkgfile";;
	devel/nosign)	echo "${WRKDIR}/pkgfile";;
	*)		echo "nopkgfile";;
	esac
else
	_outdated=0
fi

# robsd-ports-exec.sh
_exec=1
if [ "$3" = "clean=all" ]; then
	:
elif [ "$3" = "package" ]; then
	:
elif [ "$3" = "install" ]; then
	:
else
	_exec=0
fi

if [ "$_outdated" -eq 0 ] && [ "$_exec" -eq 0 ]; then
	echo "fatal: ${0}: ${@}" 1>&2
	exit 1
fi

exit 0
EOF
chmod u+x "${BINDIR}/make"

cat <<'EOF' >"${BINDIR}/pkg_info"
#!/bin/sh

shift 2 # -S -Dunsigned
case "$1" in
${WRKDIR}/pkgfile)	echo "Signature: signature ok";;
*)			echo "Signature: signature outdated";;
esac
EOF
chmod u+x "${BINDIR}/pkg_info"

ROBSDPORTS="${EXECDIR}/robsd-ports"

if testcase "basic"; then
	robsd_config - "robsd-ports" <<-EOF
	$(cat "${WRKDIR}/robsd-ports.conf")
	PORTS="devel/updated devel/nopkg devel/nosign"
	EOF
	mkdir "$ROBSDDIR"

	if ! PATH="${BINDIR}:${PATH}" WRKDIR="$WRKDIR" sh "$ROBSDPORTS" \
	   -s cvs -s proot >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	_builddir="${ROBSDDIR}/$(date '+%Y-%m-%d').1"

	assert_file - "${_builddir}/tmp/outdated" <<-EOF
	devel/nopkg
	devel/nosign
	EOF

	# Remove unstable output.
	sed -e '/running as pid/d' "${_builddir}/robsd.log" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	robsd-ports: using directory ${_builddir} at step 1
	robsd-ports: skipping steps: cvs proot
	robsd-ports: step env
	robsd-ports: step cvs skipped
	robsd-ports: step proot skipped
	robsd-ports: step outdated
	robsd-ports: step devel/nopkg
	robsd-ports: step devel/nosign
	robsd-ports: step distrib
	robsd-ports: step end
	robsd-ports: trap exit 0
	EOF
fi

if testcase "skip"; then
	robsd_config - "robsd-ports" <<-EOF
	$(cat "${WRKDIR}/robsd-ports.conf")
	PORTS="devel/nopkg devel/nosign"
	EOF
	mkdir "$ROBSDDIR"

	if ! PATH="${BINDIR}:${PATH}" WRKDIR="$WRKDIR" sh "$ROBSDPORTS" \
	   -s cvs -s proot -s distrib >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	_builddir="${ROBSDDIR}/$(date '+%Y-%m-%d').1"

	# Remove unstable output.
	sed -e '/running as pid/d' "${_builddir}/robsd.log" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	robsd-ports: using directory ${_builddir} at step 1
	robsd-ports: skipping steps: cvs proot distrib
	robsd-ports: step env
	robsd-ports: step cvs skipped
	robsd-ports: step proot skipped
	robsd-ports: step outdated
	robsd-ports: step devel/nopkg
	robsd-ports: step devel/nosign
	robsd-ports: step distrib skipped
	robsd-ports: step end
	robsd-ports: trap exit 0
	EOF
fi
