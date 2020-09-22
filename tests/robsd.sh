WRKDIR="$(mktemp -d -t robsd.XXXXXX)"
TSHCLEAN="${TSHCLEAN} ${WRKDIR}"

BUILDDIR="${TSHDIR}/build"
PATH="${WRKDIR}/bin:${PATH}"
ROBSD="${EXECDIR}/robsd"

# Stub utilities.
mkdir -p "${WRKDIR}/bin"

cat <<EOF >"${WRKDIR}/bin/id"
echo 0
EOF
chmod u+x "${WRKDIR}/bin/id"

cat <<EOF >"${WRKDIR}/bin/sendmail"
exit 0
EOF
chmod u+x "${WRKDIR}/bin/sendmail"

cat <<EOF >"${WRKDIR}/bin/sysctl"
if [ "\$2" = "hw.perfpolicy" ]; then
	echo auto
else
	/usr/sbin/sysctl "$@"
fi
EOF
chmod u+x "${WRKDIR}/bin/sysctl"

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
	: >"${WRKDIR}/exec/${_stage}.sh"
done

if testcase "basic"; then
	config_stub
	mkdir -p "$BUILDDIR"
	EXECDIR="${WRKDIR}/exec" sh "$ROBSD" >"$TMP1" 2>&1
	if [ -e "${BUILDDIR}/.running" ]; then
		fail - "lock not removed" <"$TMP1"
	fi
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
