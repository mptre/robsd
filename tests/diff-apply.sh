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
	if ! (cd "$TSHDIR" && diff_apply -u nobody "$DIFF"); then
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
	if ! (cd "$TSHDIR" && diff_apply -u nobody "$DIFF"); then
		fail "failed to apply diff"
	fi
	assert_file - "${TSHDIR}/foo" <<-EOF
	int main(void) {
		int x = 1;
		return x;
	}
	EOF
fi
