TMP1="${TSHDIR}/tmp1"
TMP2="${TSHDIR}/tmp2"

if testcase "step exit non-zero"; then
	cat <<-EOF >"$TMP1"
	error
	EOF
	ports_report_log -e 1 -n test -l "$TMP1" -t "$TSHDIR" >"$TMP2"
	assert_file "$TMP2" - <<-EOF

	error
	EOF
fi

if testcase "diff present"; then
	cat <<-EOF >"$TMP1"
	skip me...
	--- PLIST.orig
	+++ PLIST
	@@ -1 +1 @@
	-a
	+b
	EOF
	ports_report_log -e 0 -n test -l "$TMP1" -t "$TSHDIR" >"$TMP2"
	assert_file "$TMP2" - <<-EOF

	--- PLIST.orig
	+++ PLIST
	@@ -1 +1 @@
	-a
	+b
	EOF
fi

if testcase "diff absent"; then
	cat <<-EOF >"$TMP1"
	no diff
	EOF
	ports_report_log -e 0 -n test -l "$TMP1" -t "$TSHDIR" >"$TMP2"
	assert_file "$TMP2" - <<-EOF

	no diff
	EOF
fi
