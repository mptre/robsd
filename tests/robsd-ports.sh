robsd_mock >"$TMP1"; read -r WRKDIR BINDIR ROBSDDIR <"$TMP1"

# Default configuration.
cat <<EOF >"${WRKDIR}/robsd-ports.conf"
ROBSDDIR=${ROBSDDIR}
EXECDIR=${EXECDIR}
CHROOT=${TSHDIR}
PORTSDIR=/ports
PORTSUSER=nobody
EOF

cat <<'EOF' >"${BINDIR}/dpb"
#!/bin/sh

mkdir -p "${CHROOT}${PORTSDIR}/logs/$(machine)/paths/devel"
touch "${CHROOT}${PORTSDIR}/logs/$(machine)/paths/devel/outdated.log"
EOF
chmod u+x "${BINDIR}/dpb"

ROBSDPORTS="${EXECDIR}/robsd-ports"

if testcase "basic"; then
	robsd_config - "robsd-ports" <<-EOF
	$(cat "${WRKDIR}/robsd-ports.conf")
	PORTS="devel/updated devel/outdated"
	EOF
	mkdir "$ROBSDDIR"

	if ! PATH="${BINDIR}:${PATH}" WRKDIR="$WRKDIR" sh "$ROBSDPORTS" \
	   -s cvs -s proot >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	_builddir="$(find "${ROBSDDIR}" -type d -mindepth 1 -maxdepth 1)"

	if grep -q 'step="devel/updated"' "${_builddir}/steps"; then
		fail - "unexpected step devel/updated" <"${_builddir}/steps"
	fi
	if ! grep -q 'name="devel/outdated"' "${_builddir}/steps"; then
		fail - "expected step devel/outdated" <"${_builddir}/steps"
	fi

	# Remove unstable output.
	sed -e '/running as pid/d' "${_builddir}/robsd.log" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	robsd-ports: using directory ${_builddir} at step 1
	robsd-ports: skipping steps: cvs proot
	robsd-ports: step env
	robsd-ports: step cvs skipped
	robsd-ports: step proot skipped
	robsd-ports: step dpb
	robsd-ports: step distrib
	robsd-ports: step end
	robsd-ports: trap exit 0
	EOF
fi

if testcase "skip"; then
	robsd_config - "robsd-ports" <<-EOF
	$(cat "${WRKDIR}/robsd-ports.conf")
	PORTS="devel/updated devel/outdated"
	EOF
	mkdir "$ROBSDDIR"

	if ! PATH="${BINDIR}:${PATH}" WRKDIR="$WRKDIR" sh "$ROBSDPORTS" \
	   -s cvs -s proot -s distrib >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	_builddir="$(find "${ROBSDDIR}" -type d -mindepth 1 -maxdepth 1)"

	# Remove unstable output.
	sed -e '/running as pid/d' "${_builddir}/robsd.log" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	robsd-ports: using directory ${_builddir} at step 1
	robsd-ports: skipping steps: cvs proot distrib
	robsd-ports: step env
	robsd-ports: step cvs skipped
	robsd-ports: step proot skipped
	robsd-ports: step dpb
	robsd-ports: step distrib skipped
	robsd-ports: step end
	robsd-ports: trap exit 0
	EOF
fi
