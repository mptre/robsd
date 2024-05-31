portable no

robsd_mock >"$TMP1"; read -r _ BINDIR CANVASDIR <"$TMP1"

setup() {
	unset ROBSDCONF
	mkdir "$CANVASDIR"
}

CANVAS="${EXECDIR}/canvas"

if testcase "basic"; then
	robsd_config -c - <<-EOF
	canvas-dir "${CANVASDIR}"
	step "first" command { "true" }
	EOF

	if ! PATH="${BINDIR}:${PATH}" sh "$CANVAS" -d -C "$ROBSDCONF" \
	   >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
fi

if testcase "skip"; then
	robsd_config -c - <<-EOF
	canvas-dir "${CANVASDIR}"
	skip { "first" }
	step "first" command { "true" }
	step "second" command { "true" }
	EOF

	if ! sh "$CANVAS" -d -C "$ROBSDCONF" -s second >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi

	_builddir="$(find "${ROBSDDIR}" -type d -mindepth 1 -maxdepth 1)"
	_steps="$(step_path "$_builddir")"
	step_eval -n first "$_steps"
	if [ "$(step_value skip)" -ne 1 ]; then
		fail "expected first to be skipped"
	fi
	step_eval -n second "$_steps"
	if [ "$(step_value skip)" -ne 1 ]; then
		fail "expected second to be skipped"
	fi
fi

if testcase "invalid: missing configuration argument"; then
	if sh "$CANVAS" -d >"$TMP1" 2>&1; then
		fail - "expected exit non-zero" <"$TMP1"
	fi
	if ! grep -q usage "$TMP1"; then
		fail - "expected usage" <"$TMP1"
	fi
fi
