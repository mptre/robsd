portable no

if testcase "failure"; then
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF

	# shellcheck disable=SC2016
	if echo '${undefined}' | TMPDIR=${TSHDIR} config_load >"$TMP1" 2>&1; then
		fail - "expected exit non-zero" <"$TMP1"
	fi
	find "$TSHDIR" -type f -name 'robsd.*' \! -name 'robsd.conf' >"$TMP1"
	assert_file - "$TMP1" </dev/null
fi
