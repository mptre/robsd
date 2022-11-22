export WRKDIR
robsd_mock >"$TMP1"; read -r WRKDIR BINDIR ROBSDDIR <"$TMP1"

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

	robsd_config - <<-EOF
	robsddir "${ROBSDDIR}"
	execdir "${EXECDIR}"
	bsd-diff "/var/empty"
	EOF

	mkdir -p "${ROBSDDIR}/2020-09-01.1" "${ROBSDDIR}/2020-09-02.1"
	mkdir "${ROBSDDIR}/2020-09-02.1/tmp"
	: >"$(step_path "${ROBSDDIR}/2020-09-02.1")"

	[ "$_patch" -eq 0 ] && return 0

	step_serialize -n patch >"$(step_path "${ROBSDDIR}/2020-09-02.1")"

	diff_create >"${ROBSDDIR}/2020-09-02.1/src.diff.1"
	cat <<-EOF >"${TSHDIR}/foo"
	int main(void) {
		int x = 0;
		return x;
	}
	EOF
}

if testcase "basic"; then
	setup
	(cd "$TSHDIR" && patch -s <"${ROBSDDIR}/2020-09-02.1/src.diff.1")

	if ! PATH="${BINDIR}:${PATH}" sh "$ROBSDRESCUE" >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	assert_file - "$TMP1" <<-EOF
	robsd-rescue: using release directory ${ROBSDDIR}/2020-09-02.1
	robsd-rescue: reverting diff ${ROBSDDIR}/2020-09-02.1/src.diff.1
	robsd-rescue: released lock
	EOF
fi

if testcase "patch already reverted"; then
	setup
	if ! PATH="${BINDIR}:${PATH}" sh "$ROBSDRESCUE" >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	assert_file - "$TMP1" <<-EOF
	robsd-rescue: using release directory ${ROBSDDIR}/2020-09-02.1
	robsd-rescue: diff already reverted ${ROBSDDIR}/2020-09-02.1/src.diff.1
	robsd-rescue: released lock
	EOF
fi

if testcase "patch step absent"; then
	setup -P
	if ! PATH="${BINDIR}:${PATH}" sh "$ROBSDRESCUE" >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	assert_file - "$TMP1" <<-EOF
	robsd-rescue: using release directory ${ROBSDDIR}/2020-09-02.1
	robsd-rescue: step patch not found, cannot revert diff(s)
	robsd-rescue: released lock
	EOF
fi

if testcase "lock already acquired"; then
	setup -P
	echo "${ROBSDDIR}/2020-09-01.1" >"${ROBSDDIR}/.running"
	if PATH="${BINDIR}:${PATH}" sh "$ROBSDRESCUE" >"$TMP1" 2>&1; then
		fail - "expected exit non-zero" <"$TMP1"
	fi
fi
