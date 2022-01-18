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
	if ! (cd "$TSHDIR" && diff_apply -t "$TSHDIR" -u nobody "$DIFF"); then
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
	if ! (cd "$TSHDIR" && diff_apply -t "$TSHDIR" -u nobody "$DIFF"); then
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
	echo new >"${TSHDIR}/patch/dir/new"
	(cd "$TSHDIR" &&
	 diff -u -L patch/dir/new -L patch/dir/new /dev/null patch/dir/new) >"$DIFF" || :
	rm -r "${TSHDIR}/patch/dir"
	if ! (cd "$TSHDIR" && diff_apply -t "$TSHDIR" -u nobody "$DIFF"); then
		fail "failed to apply diff"
	fi
	echo new | assert_file - "${TSHDIR}/patch/dir/new"
fi

if testcase "failure"; then
	cat <<-EOF >"${TSHDIR}/foo"
	int main(void) {
		int x = 0;
		return x;
	}
	EOF
	diff_create >"$DIFF"
	if (cd "/var/empty" && diff_apply -t "$TSHDIR" -u nobody "$DIFF" >"$TMP1" 2>&1); then
		fail "expected exit non-zero"
	fi
	if ! [ -s "$TMP1" ]; then
		fail "expected some output"
	fi
fi
