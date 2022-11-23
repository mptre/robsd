robsd_mock >"$TMP1"; read -r WRKDIR BINDIR ROBSDDIR <"$TMP1"

ROBSD="${EXECDIR}/robsd"

# Create exec directory and stub some steps.
mkdir -p "${WRKDIR}/exec"
for _copy in \
	robsd-dmesg.sh \
	util.sh \
	util-ports.sh \
	util-regress.sh
do
	cp "${EXECDIR}/${_copy}" "${WRKDIR}/exec"
done
for _stage in \
	env \
        cvs \
        patch \
        kernel \
        reboot \
        base \
        release \
        checkflist \
        xbase \
        xrelease \
        image \
	hash \
        revert \
        distrib
do
	: >"${WRKDIR}/exec/robsd-${_stage}.sh"
done

if testcase "basic"; then
	# Ensure hook exit status is ignored.
	_hook="${TSHDIR}/hook.sh"
	cat <<-'EOF' >"$_hook"
	if [ "$2" = "end" ]; then
		echo stdout
		echo stderr 1>&2
		exit 1
	fi
	EOF

	robsd_config - <<-EOF
	robsddir "${ROBSDDIR}"
	execdir "${WRKDIR}/exec"
	hook { "sh" "${_hook}" "\${builddir}" "\${step}" }
	EOF
	mkdir -p "$ROBSDDIR"
	echo "Index: dir/file.c" >"${TSHDIR}/src-one.diff"
	echo "Index: dir/file.c" >"${TSHDIR}/src-two.diff"
	echo "Index: dir/file.c" >"${TSHDIR}/xenocara.diff"

	_fail="${TSHDIR}/fail"
	env PATH="${BINDIR}:${PATH}" \
		sh "$ROBSD" -d \
		-S "${TSHDIR}/src-one.diff" \
		-S "${TSHDIR}/src-two.diff" \
		-X "${TSHDIR}/xenocara.diff" \
		-s reboot -t daily \
		>"$TMP1" 2>&1 || : >"$_fail"
	if [ -e "$_fail" ]; then
		fail - "expected exit zero" <"$TMP1"
	fi
	if [ -e "${ROBSDDIR}/.running" ]; then
		fail - "lock not removed" <"$TMP1"
	fi
	_builddir="$(find "${ROBSDDIR}" -type d -mindepth 1 -maxdepth 1)"

	assert_file - "${_builddir}/comment" <<-EOF
	Applied the following diff(s):
	${TSHDIR}/src-one.diff
	${TSHDIR}/src-two.diff
	${TSHDIR}/xenocara.diff
	EOF

	echo daily | assert_file - "${_builddir}/tags"

	# Remove unstable output.
	sed -i \
		-e '/running as pid/d' \
		-e '/^\+ /d' \
		"$TMP1"
	_user="$(logname)"
	assert_file - "$TMP1" <<-EOF
	robsd: using directory ${_builddir} at step 1
	robsd: using diff ${TSHDIR}/src-one.diff rooted in ${TSHDIR}
	robsd: using diff ${TSHDIR}/src-two.diff rooted in ${TSHDIR}
	robsd: using diff ${TSHDIR}/xenocara.diff rooted in ${TSHDIR}
	robsd: skipping steps: reboot
	robsd: step env
	robsd-hook: exec "sh" "${_hook}" "${_builddir}" "env"
	robsd: step cvs
	robsd-hook: exec "sh" "${_hook}" "${_builddir}" "cvs"
	robsd: step patch
	robsd-hook: exec "sh" "${_hook}" "${_builddir}" "patch"
	robsd: step kernel
	robsd-hook: exec "sh" "${_hook}" "${_builddir}" "kernel"
	robsd: step reboot skipped
	robsd: step env
	robsd-hook: exec "sh" "${_hook}" "${_builddir}" "env"
	robsd: step base
	robsd-hook: exec "sh" "${_hook}" "${_builddir}" "base"
	robsd: step release
	robsd-hook: exec "sh" "${_hook}" "${_builddir}" "release"
	robsd: step checkflist
	robsd-hook: exec "sh" "${_hook}" "${_builddir}" "checkflist"
	robsd: step xbase
	robsd-hook: exec "sh" "${_hook}" "${_builddir}" "xbase"
	robsd: step xrelease
	robsd-hook: exec "sh" "${_hook}" "${_builddir}" "xrelease"
	robsd: step image
	robsd-hook: exec "sh" "${_hook}" "${_builddir}" "image"
	robsd: step hash
	robsd-hook: exec "sh" "${_hook}" "${_builddir}" "hash"
	robsd: step revert
	robsd-hook: exec "sh" "${_hook}" "${_builddir}" "revert"
	robsd: step distrib
	robsd-hook: exec "sh" "${_hook}" "${_builddir}" "distrib"
	robsd: step dmesg
	robsd-hook: exec "sh" "${_hook}" "${_builddir}" "dmesg"
	robsd: step end
	robsd-hook: exec "sh" "${_hook}" "${_builddir}" "end"
	stdout
	stderr
	robsd: trap exit 0
	EOF
fi

if testcase "reboot"; then
	robsd_config - <<-EOF
	robsddir "${ROBSDDIR}"
	execdir "${WRKDIR}/exec"
	reboot yes
	EOF
	mkdir -p "$ROBSDDIR"

	_fail="${TSHDIR}/fail"
	PATH="${BINDIR}:${PATH}" sh "$ROBSD" -d >"$TMP1" 2>&1 || : >"$_fail"
	if [ -e "$_fail" ]; then
		fail - "expected exit zero" <"$TMP1"
	fi

	_builddir="$(find "${ROBSDDIR}" -type d -mindepth 1 -maxdepth 1)"
	if [ -e "${_builddir}/report" ]; then
		fail - "expected no report" <"$TMP1"
	fi
fi

if testcase "already running"; then
	robsd_config - <<-EOF
	robsddir "${ROBSDDIR}"
	EOF
	mkdir -p "$ROBSDDIR"
	echo /var/empty >"${ROBSDDIR}/.running"
	PATH="${BINDIR}:${PATH}" sh "$ROBSD" -d 2>&1 | grep -v 'using ' >"$TMP1"
	if ! [ -e "${ROBSDDIR}/.running" ]; then
		fail - "lock not preserved" <"$TMP1"
	fi
	assert_file - "$TMP1" <<-EOF
	robsd: /var/empty: lock already acquired
	robsd: trap exit 1
	EOF
fi

if testcase "already running detached"; then
	robsd_config - <<-EOF
	robsddir "${ROBSDDIR}"
	EOF
	mkdir -p "$ROBSDDIR"
	echo /var/empty >"${ROBSDDIR}/.running"
	PATH="${BINDIR}:${PATH}" sh "$ROBSD" 2>&1 | grep -v 'using ' >"$TMP1"
	if ! [ -e "${ROBSDDIR}/.running" ]; then
		fail - "lock not preserved" <"$TMP1"
	fi
	assert_file - "$TMP1" <<-EOF
	robsd: /var/empty: lock already acquired
	robsd: trap exit 1
	EOF
fi

if testcase "early failure"; then
	robsd_config - <<-EOF
	robsddir "${ROBSDDIR}"
	EOF
	echo 'echo 0' >"${BINDIR}/sysctl"
	mkdir -p "$ROBSDDIR"
	if PATH="${BINDIR}:${PATH}" sh "$ROBSD" -d >"$TMP1" 2>&1; then
		fail - "expected exit non-zero" <"$TMP1"
	fi
	assert_file - "$TMP1" <<-EOF
	robsd: non-optimal performance detected, check hw.perfpolicy and hw.setperf
	robsd: trap exit 1
	EOF
fi
