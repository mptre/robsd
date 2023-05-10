portable no

robsd_mock >"$TMP1"; read -r _ BINDIR ROBSDDIR <"$TMP1"

cat <<'EOF' >"${BINDIR}/dpb"
#!/bin/sh

echo "$@"
EOF
chmod u+x "${BINDIR}/dpb"

# robsd_ports [robsd-ports-argument ...]
robsd_ports() (
	PATH="${BINDIR}:${PATH}"
	export PATH PORTS TSHDIR
	sh "${EXECDIR}/robsd-ports" "$@"
)

if testcase "basic"; then
	robsd_config -P - <<-EOF
	robsddir "${ROBSDDIR}"
	ports { "devel/updated" "devel/outdated" }
	EOF
	mkdir "$ROBSDDIR" "${TSHDIR}/ports"
	echo '# comment' >"${TSHDIR}/ports/Makefile"
	cat <<-EOF >"${TSHDIR}/ports.diff"
	--- Makefile
	+++ Makefile
	@@ -1 +1,2 @@
	 # comment 
	+# comment 
	EOF

	mkdir -p "${TSHDIR}/ports/packages/$(machine)/all"

	if ! robsd_ports -d -P "${TSHDIR}/ports.diff" -s cvs -s clean -s proot \
	   >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	_builddir="$(find "${ROBSDDIR}" -type d -mindepth 1 -maxdepth 1)"

	# Remove unstable output.
	sed -e '/running as pid/d' "${_builddir}/robsd.log" >"$TMP1"
	assert_file - "$TMP1" <<-EOF
	robsd-ports: using directory ${_builddir} at step 1
	robsd-ports: using diff ${TSHDIR}/ports.diff rooted in ${TSHDIR}/ports
	robsd-ports: skipping steps: cvs clean proot
	robsd-ports: step env
	robsd-ports: step cvs skipped
	robsd-ports: step clean skipped
	robsd-ports: step proot skipped
	robsd-ports: step patch
	robsd-ports: step dpb
	robsd-ports: step distrib
	robsd-ports: step revert
	robsd-ports: reverting diff ${_builddir}/ports.diff.1
	robsd-ports: step dmesg
	robsd-ports: step end
	robsd-ports: trap exit 0
	EOF

	assert_file - "${_builddir}/tmp/ports" <<-EOF
	devel/updated
	devel/outdated
	EOF
fi

if testcase "oneshot"; then
	robsd_config -P - <<-EOF
	robsddir "${ROBSDDIR}"
	ports { "devel/ignored" }
	EOF
	mkdir "$ROBSDDIR"
	mkdir -p "${TSHDIR}/ports/packages/$(machine)/all"

	if ! robsd_ports -d -s cvs -s clean -s proot devel/favored \
	   >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	_builddir="$(find "${ROBSDDIR}" -type d -mindepth 1 -maxdepth 1)"

	assert_file - "${_builddir}/tmp/ports" <<-EOF
	devel/favored
	EOF
fi
