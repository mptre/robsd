portable no

# Stub for su expected to call patch.
su() (
	shift 2 # strip of su $login
	# shellcheck disable=SC2068
	$@
)

DIFF="${TSHDIR}/diff"

if testcase "basic"; then
	cat <<-EOF >"${TSHDIR}/foo"
	int main(void) {
		int x = 0;
		return x;
	}
	EOF
	diff_create >"${DIFF}"
	if ! diff_apply -d "${TSHDIR}" -t "${TSHDIR}" -u nobody "${DIFF}"; then
		fail "failed to apply diff"
	fi
	assert_file - "${TSHDIR}/foo" <<-EOF
	int main(void) {
		int x = 1;
		return x;
	}
	EOF
fi

if testcase "already applied"; then
	cat <<-EOF >"${TSHDIR}/foo"
	int main(void) {
		int x = 1;
		return x;
	}
	EOF
	diff_create >"${DIFF}"
	if ! diff_apply -d "${TSHDIR}" -t "${TSHDIR}" -u nobody "${DIFF}"; then
		fail "failed to apply diff"
	fi
	assert_file - "${TSHDIR}/foo" <<-EOF
	int main(void) {
		int x = 1;
		return x;
	}
	EOF
fi

if testcase "new directory"; then
	mkdir -p "${TSHDIR}/patch/not-empty"
	echo a >"${TSHDIR}/patch/not-empty/a"
	echo b >"${TSHDIR}/patch/not-empty/b"
	mkdir -p "${TSHDIR}/patch/empty"
	echo a >"${TSHDIR}/patch/empty/a"
	echo b >"${TSHDIR}/patch/empty/b"
	{
		cd "${TSHDIR}"
		diff -u -L patch/not-empty/b -L patch/not-empty/b /dev/null patch/not-empty/b || :
		diff -u -L patch/empty/a -L patch/empty/a /dev/null patch/empty/a || :
		diff -u -L patch/empty/b -L patch/empty/b /dev/null patch/empty/b || :
	} >"${DIFF}"
	rm -r "${TSHDIR}/patch/not-empty/b" "${TSHDIR}/patch/empty"
	if ! diff_apply -d "${TSHDIR}" -t "${TSHDIR}" -u nobody "${DIFF}"; then
		fail "failed to apply diff"
	fi
	echo a | assert_file - "${TSHDIR}/patch/not-empty/a"
	echo b | assert_file - "${TSHDIR}/patch/not-empty/b"
	echo a | assert_file - "${TSHDIR}/patch/empty/a"
	echo b | assert_file - "${TSHDIR}/patch/empty/b"

	if ! diff_revert -d "${TSHDIR}" -t "${TSHDIR}" -u nobody "${DIFF}" >"${TMP1}" 2>&1; then
		fail - "failed to revert diff" <"${TMP1}"
	fi
	assert_file - "${TMP1}" <<-EOF
	robsd-test: reverting diff ${DIFF}
	robsd-test: removing empty directory ${TSHDIR}/patch/empty
	EOF

	if [ -d "${TSHDIR}/patch/empty" ]; then
		find "${TSHDIR}" -type d -mindepth 2 |
		fail - "expected empty directory to be removed"
	fi
fi

if testcase "failure"; then
	cat <<-EOF >"${TSHDIR}/foo"
	int main(void) {
		int x = 0;
		return x;
	}
	EOF
	diff_create >"${DIFF}"
	if diff_apply -d "/var/empty" -t "${TSHDIR}" -u nobody "${DIFF}" >"${TMP1}" 2>&1; then
		fail "expected exit non-zero"
	fi
	if ! [ -s "${TMP1}" ]; then
		fail "expected some output"
	fi
fi
