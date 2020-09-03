WRKDIR="$(mktemp -d -t robsd.XXXXXX)"
TSHCLEAN="${TSHCLEAN} ${WRKDIR}"

BUILDDIR="${TSHDIR}/build"
PATH="${WRKDIR}/bin:${PATH}"
ROBSDRESCUE="${EXECDIR}/robsd-rescue"

# Stub utilities.
mkdir -p "${WRKDIR}/bin"

cat <<EOF >"${WRKDIR}/bin/id"
echo 0
EOF
chmod u+x "${WRKDIR}/bin/id"

cat <<EOF >"${WRKDIR}/bin/su"
shift 2 # strip of su login
\$@
EOF
chmod u+x "${WRKDIR}/bin/su"

setup() {
	config_stub - <<-EOF
	BSDDIFF=${TSHDIR}/src.diff.1
	EOF

	diff_create >"${TSHDIR}/src.diff.1"
	cat <<-EOF >"${TSHDIR}/foo"
	int main(void) {
		int x = 0;
		return x;
	}
	EOF

	mkdir -p "${BUILDDIR}/2020-09-01.1" "${BUILDDIR}/2020-09-02.1"
	cat <<-EOF >"${BUILDDIR}/2020-09-02.1/steps"
	step="1" name="patch" exit="0"
	EOF
}

if testcase "basic"; then
	setup
	(cd "$TSHDIR" && patch -s <"${TSHDIR}/src.diff.1")

	sh "$ROBSDRESCUE" >"$TMP1" 2>&1
	assert_file - "$TMP1" <<-EOF
	robsd-rescue: using release directory ${TSHDIR}/build/2020-09-02.1
	robsd-rescue: reverting diff ${TSHDIR}/src.diff.1
	EOF
fi

if testcase "patch already reverted"; then
	setup
	sh "$ROBSDRESCUE" >"$TMP1" 2>&1
	assert_file - "$TMP1" <<-EOF
	robsd-rescue: using release directory ${TSHDIR}/build/2020-09-02.1
	robsd-rescue: diff already reverted ${TSHDIR}/src.diff.1
	EOF
fi

if testcase "patch step absent"; then
	setup
	: >"${BUILDDIR}/2020-09-02.1/steps"
	if sh "$ROBSDRESCUE" >"$TMP1" 2>&1; then
		fail "want exit 1, got 0"
	fi
	assert_file - "$TMP1" <<-EOF
	robsd-rescue: using release directory ${TSHDIR}/build/2020-09-02.1
	robsd-rescue: step patch not found
	EOF
fi
