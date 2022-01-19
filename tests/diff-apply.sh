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
	diff_create >"$DIFF"
	if ! diff_apply -d "$TSHDIR" -t "$TSHDIR" -u nobody "$DIFF"; then
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
	diff_create >"$DIFF"
	if ! diff_apply -d "$TSHDIR" -t "$TSHDIR" -u nobody "$DIFF"; then
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
	mkdir -p "${TSHDIR}/patch/dir"
	echo a >"${TSHDIR}/patch/dir/a"
	echo b >"${TSHDIR}/patch/dir/b"
	{
		cd "$TSHDIR"
		diff -u -L patch/dir/a -L patch/dir/a /dev/null patch/dir/a || :
		diff -u -L patch/dir/b -L patch/dir/b /dev/null patch/dir/b || :
	} >"$DIFF"
	rm -r "${TSHDIR}/patch/dir"
	if ! diff_apply -d "$TSHDIR" -t "$TSHDIR" -u nobody "$DIFF"; then
		fail "failed to apply diff"
	fi
	echo a | assert_file - "${TSHDIR}/patch/dir/a"
	echo b | assert_file - "${TSHDIR}/patch/dir/b"

	if ! diff_revert -d "$TSHDIR" -t "$TSHDIR" -u nobody "$DIFF" >"$TMP1" 2>&1; then
		fail - "failed to revert diff" <"$TMP1"
	fi
	assert_file - "$TMP1" <<-EOF
	robsd-test: reverting diff ${DIFF}
	robsd-test: removing empty directory patch/dir
	EOF

	if [ -d "${TSHDIR}/patch/dir" ]; then
		find "$TSHDIR" -type d -mindepth 2 |
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
	diff_create >"$DIFF"
	if diff_apply -d "/var/empty" -t "$TSHDIR" -u nobody "$DIFF" >"$TMP1" 2>&1; then
		fail "expected exit non-zero"
	fi
	if ! [ -s "$TMP1" ]; then
		fail "expected some output"
	fi
fi
