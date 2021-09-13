export WRKDIR
utility_setup >"$TMP1"; read -r WRKDIR BINDIR BUILDDIR <"$TMP1"

ROBSDRESCUE="${EXECDIR}/robsd-rescue"

# setup [-P]
setup() {
	local _patch=1

	while [ $# -gt 0 ]; do
		case "$1" in
		-P)	_patch=0;;
		*)	break;;
		esac
		shift
	done

	config_stub - <<-EOF
	BUILDDIR=${BUILDDIR}
	BSDDIFF=/var/empty
	EOF

	mkdir -p "${BUILDDIR}/2020-09-01.1" "${BUILDDIR}/2020-09-02.1"
	: >"${BUILDDIR}/2020-09-02.1/steps"

	[ "$_patch" -eq 0 ] && return 0

	cat <<-EOF >"${BUILDDIR}/2020-09-02.1/steps"
	step="1" name="patch" exit="0"
	EOF

	diff_create >"${BUILDDIR}/2020-09-02.1/src.diff.1"
	cat <<-EOF >"${TSHDIR}/foo"
	int main(void) {
		int x = 0;
		return x;
	}
	EOF
}

if testcase "basic"; then
	setup
	(cd "$TSHDIR" && patch -s <"${BUILDDIR}/2020-09-02.1/src.diff.1")

	if ! PATH="${BINDIR}:${PATH}" sh "$ROBSDRESCUE" >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	assert_file - "$TMP1" <<-EOF
	robsd-rescue: using release directory ${BUILDDIR}/2020-09-02.1
	robsd-rescue: reverting diff ${BUILDDIR}/2020-09-02.1/src.diff.1
	EOF
fi

if testcase "patch already reverted"; then
	setup
	if ! PATH="${BINDIR}:${PATH}" sh "$ROBSDRESCUE" >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	assert_file - "$TMP1" <<-EOF
	robsd-rescue: using release directory ${BUILDDIR}/2020-09-02.1
	robsd-rescue: diff already reverted ${BUILDDIR}/2020-09-02.1/src.diff.1
	EOF
fi

if testcase "patch step absent"; then
	setup -P
	if ! PATH="${BINDIR}:${PATH}" sh "$ROBSDRESCUE" >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	assert_file - "$TMP1" <<-EOF
	robsd-rescue: using release directory ${BUILDDIR}/2020-09-02.1
	robsd-rescue: step patch not found, cannot revert diff(s)
	EOF
fi

if testcase "release lock"; then
	setup -P
	echo "${BUILDDIR}/2020-09-02.1" >"${BUILDDIR}/.running"
	if ! PATH="${BINDIR}:${PATH}" sh "$ROBSDRESCUE" >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	assert_file - "$TMP1" <<-EOF
	robsd-rescue: using release directory ${BUILDDIR}/2020-09-02.1
	robsd-rescue: step patch not found, cannot revert diff(s)
	robsd-rescue: released lock
	EOF
fi
