create_diff() {
	cat <<-EOF
diff --git a/foo b/foo
index eca3934..c629ecf 100644
--- a/foo
+++ b/foo
@@ -1,4 +1,4 @@
 int main(void) {
-int x = 0;
+int x = 1;
 return x;
 }
	EOF
}

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
	create_diff >"$DIFF"
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
	create_diff >"$DIFF"
	if ! (cd "$TSHDIR" && diff_apply -u nobody "$DIFF" >/dev/null); then
		fail "failed to apply diff"
	fi
	assert_file - "${TSHDIR}/foo" <<-EOF
	int main(void) {
		int x = 1;
		return x;
	}
	EOF
fi
