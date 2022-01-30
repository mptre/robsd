robsd_mock >"$TMP1"; read -r WRKDIR BINDIR ROBSDDIR <"$TMP1"

ROBSD="${EXECDIR}/robsd"

# Create exec directory including all stages.
mkdir -p "${WRKDIR}/exec"
cp "${EXECDIR}/util.sh" "${WRKDIR}/exec"
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
	cat <<-EOF >"$_hook"
	if [ "\$2" = "end" ]; then
		echo stdout
		echo stderr 1>&2
		exit 1
	fi
	EOF
	chmod u+x "$_hook"

	robsd_config - <<-EOF
	robsddir "${ROBSDDIR}"
	execdir "${WRKDIR}/exec"
	hook "${_hook}"
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
	sed -i -e '/running as pid/d' -e '/robsd-exec:/d' "$TMP1"
	_user="$(logname)"
	assert_file - "$TMP1" <<-EOF
	robsd: using directory ${_builddir} at step 1
	robsd: using diff ${TSHDIR}/src-one.diff rooted in ${TSHDIR}
	robsd: using diff ${TSHDIR}/src-two.diff rooted in ${TSHDIR}
	robsd: using diff ${TSHDIR}/xenocara.diff rooted in ${TSHDIR}
	robsd: skipping steps: reboot
	robsd: step env
	robsd: step cvs
	robsd: invoking hook: ${_hook} ${_builddir} cvs 0 ${_user}
	robsd: step patch
	robsd: invoking hook: ${_hook} ${_builddir} patch 0 ${_user}
	robsd: step kernel
	robsd: invoking hook: ${_hook} ${_builddir} kernel 0 ${_user}
	robsd: step reboot skipped
	robsd: step env
	robsd: step base
	robsd: invoking hook: ${_hook} ${_builddir} base 0 ${_user}
	robsd: step release
	robsd: invoking hook: ${_hook} ${_builddir} release 0 ${_user}
	robsd: step checkflist
	robsd: invoking hook: ${_hook} ${_builddir} checkflist 0 ${_user}
	robsd: step xbase
	robsd: invoking hook: ${_hook} ${_builddir} xbase 0 ${_user}
	robsd: step xrelease
	robsd: invoking hook: ${_hook} ${_builddir} xrelease 0 ${_user}
	robsd: step image
	robsd: invoking hook: ${_hook} ${_builddir} image 0 ${_user}
	robsd: step hash
	robsd: invoking hook: ${_hook} ${_builddir} hash 0 ${_user}
	robsd: step revert
	robsd: invoking hook: ${_hook} ${_builddir} revert 0 ${_user}
	robsd: step distrib
	robsd: invoking hook: ${_hook} ${_builddir} distrib 0 ${_user}
	robsd: step end
	robsd: invoking hook: ${_hook} ${_builddir} end 0 ${_user}
	stdout
	stderr
	robsd: trap exit 0
	EOF
fi

if testcase "reboot"; then
	robsd_config - <<-EOF
	robsddir "${ROBSDDIR}"
	execdir "${WRKDIR}/exec"
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
	echo 'exit 0' >"${BINDIR}/sysctl"
	mkdir -p "$ROBSDDIR"
	if PATH="${BINDIR}:${PATH}" sh "$ROBSD" -d >"$TMP1" 2>&1; then
		fail - "expected exit non-zero" <"$TMP1"
	fi
	assert_file - "$TMP1" <<-EOF
	robsd: non-optimal performance detected, check hw.perfpolicy and hw.setperf
	robsd: trap exit 1
	EOF
fi
