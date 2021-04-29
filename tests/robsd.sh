utility_setup >"$TMP1"; read -r WRKDIR BUILDDIR <"$TMP1"

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
	config_stub
	mkdir -p "$BUILDDIR"
	echo "Index: dir/file.c" >"${TSHDIR}/src.diff"
	echo "Index: dir/file.c" >"${TSHDIR}/xenocara.diff"
	EXECDIR="${WRKDIR}/exec" sh "$ROBSD" \
		-S "${TSHDIR}/src.diff" -X "${TSHDIR}/xenocara.diff" \
		>"$TMP1" 2>&1
	if [ -e "${BUILDDIR}/.running" ]; then
		fail - "lock not removed" <"$TMP1"
	fi

	# Remove non stable output.
	sed -i -e '/running as pid/d' "$TMP1"
	assert_file - "$TMP1" <<-EOF
	robsd: using directory ${BUILDDIR}/$(date '+%Y-%m-%d').1 at step 1
	robsd: using diff ${TSHDIR}/src.diff rooted at ${TSHDIR}
	robsd: using diff ${TSHDIR}/xenocara.diff rooted at ${TSHDIR}
	robsd: step env
	robsd: step cvs
	robsd: step patch
	robsd: step kernel
	robsd: step reboot
	EOF
fi

if testcase "already running"; then
	config_stub
	mkdir -p "$BUILDDIR"
	echo /var/empty >"${BUILDDIR}/.running"
	EXECDIR="${WRKDIR}/exec" sh "$ROBSD" 2>&1 | grep -v 'using ' >"$TMP1"
	if ! [ -e "${BUILDDIR}/.running" ]; then
		fail - "lock not preserved" <"$TMP1"
	fi
	assert_file - "$TMP1" <<-EOF
	robsd: /var/empty: lock already acquired
	robsd: already running
	robsd: failed in step unknown
	EOF
fi

if testcase "already running detached"; then
	config_stub
	mkdir -p "$BUILDDIR"
	echo /var/empty >"${BUILDDIR}/.running"
	EXECDIR="${WRKDIR}/exec" sh "$ROBSD" -D 2>&1 | grep -v 'using ' >"$TMP1"
	if ! [ -e "${BUILDDIR}/.running" ]; then
		fail - "lock not preserved" <"$TMP1"
	fi
	assert_file - "$TMP1" <<-EOF
	robsd: /var/empty: lock already acquired
	robsd: already running
	robsd: failed in step unknown
	EOF
fi

if testcase "early failure"; then
	config_stub
	echo 'exit 0' >"${WRKDIR}/bin/sysctl"
	mkdir -p "$BUILDDIR"
	if EXECDIR="${WRKDIR}/exec" sh "$ROBSD" >"$TMP1" 2>&1; then
		fail - "expected non-zero exit" <"$TMP1"
	fi
	assert_file - "$TMP1" <<-EOF
	robsd: non-optimal performance detected, check hw.perfpolicy and hw.setperf
	robsd: failed in step unknown
	EOF
fi
