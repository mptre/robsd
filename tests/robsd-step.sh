OUT="${TSHDIR}/out"

default_steps() {
	step_serialize -s 1 -n one
	step_serialize -H -s 2 -n two
}

# robsd_step [-e] [-] -- [robsd-step-argument ...]
robsd_step() {
	local _err0=0
	local _err1=0
	local _stdin="${TSHDIR}/stdin"
	local _stdout="${TSHDIR}/stdout"

	while [ $# -gt 0 ]; do
		case "$1" in
		-e)	_err0="1";;
		-)	cat >"$_stdin";;
		*)	break;;
		esac
		shift
	done
	[ "${1:-}" = "--" ] && shift

	${EXEC:-} "$ROBSDSTEP" "$@" >"$_stdout" 2>&1 || _err1="$?"
	if [ "$_err0" -ne "$_err1" ]; then
		fail - "expected exit ${_err0}, got ${_err1}" <"$_stdout"
		return 0
	fi
	if [ -s "$_stdin" ]; then
		assert_file "$_stdin" "$_stdout"
	else
		cat "$_stdout"
	fi
}

if testcase "read: positive index"; then
	default_steps >"$TMP1"
	robsd_step -- -R -f "$TMP1" -l 1 <<-'EOF' >"$OUT"
	${step}, ${name}, ${exit}, ${duration}, ${log}, ${user}, ${time}
	EOF
	assert_file - "$OUT" <<-EOF
	1, one, 0, 1, /dev/null, root, 1666666666
	EOF
fi

if testcase "read: read: positive index boundary"; then
	default_steps >"$TMP1"
	robsd_step -- -R -f "$TMP1" -l 2 <<-'EOF' >"$OUT"
	${name}
	EOF
	assert_file - "$OUT" <<-EOF
	two
	EOF
fi

if testcase "read: positive index out of bounds"; then
	default_steps >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -l 3 <<-'EOF'
	robsd-step: step at line 3 not found
	EOF
fi

if testcase "read: negtive index"; then
	default_steps >"$TMP1"
	robsd_step -- -R -f "$TMP1" -l -1 <<-'EOF' >"$OUT"
	${name}
	EOF
	assert_file - "$OUT" <<-EOF
	two
	EOF
fi

if testcase "read: negative index boundary"; then
	default_steps >"$TMP1"
	robsd_step -- -R -f "$TMP1" -l -2 <<-'EOF' >"$OUT"
	${name}
	EOF
	assert_file - "$OUT" <<-EOF
	one
	EOF
fi

if testcase "read: negative index out of bounds"; then
	default_steps >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -l -3 <<-'EOF'
	robsd-step: step at line -3 not found
	EOF
fi

if testcase "read: index too large"; then
	default_steps >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -l $((1 << 31)) <<-'EOF'
	robsd-step: line 2147483648 too large
	EOF
fi

if testcase "read: index too small"; then
	default_steps >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -l -$((1 << 31)) <<-'EOF'
	robsd-step: line -2147483648 too small
	EOF
fi

if testcase "read: name"; then
	default_steps >"$TMP1"
	robsd_step -- -R -f "$TMP1" -n one <<-'EOF' >"$OUT"
	${name}
	EOF
	assert_file - "$OUT" <<-EOF
	one
	EOF
fi

if testcase "read: name not found"; then
	default_steps >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -n unknown <<-EOF
	robsd-step: step with name 'unknown' not found
	EOF
fi

if testcase "read: invalid index and name are mutually exclusive"; then
	default_steps >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -l 1 -n name <<-EOF
	robsd-step: -l and -n are mutually exclusive
	EOF
fi

if testcase "read: invalid no index nor name"; then
	default_steps >"$TMP1"
	robsd_step -e -- -R -f "$TMP1" >"$OUT"
	if ! grep -q usage "$OUT"; then
		fail - "expected usage" <"$OUT"
	fi
fi

if testcase "read: invalid unterminated header"; then
	printf 'step' >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -l 1 <<-EOF
	robsd-step: ${TMP1}:1: unterminated value
	EOF
fi

if testcase "read: invalid unterminated row"; then
	{ default_steps; printf '1'; } >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -l 1 <<-EOF
	robsd-step: ${TMP1}:4: unterminated value
	EOF
fi

if testcase "read: invalid column"; then
	{ printf 'step\n'; step_serialize -H -s 1 -n one; } >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -l 1 <<-EOF
	robsd-step: ${TMP1}:2: unknown column 1
	EOF
fi

if testcase "read: invalid missing key"; then
	default_steps | sed -e 's/1,one,//' >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -l 1 <<-EOF
	robsd-step: ${TMP1}:2: missing key 'time'
	EOF
fi

if testcase "read: invalid file not found"; then
	robsd_step -e - -- -R -f "${TMP1}.nein" -l 1 <<-EOF
	robsd-step: open: ${TMP1}.nein: No such file or directory
	EOF
fi

if testcase "write: new step"; then
	: >"$TMP1"
	robsd_step -- -W -f "$TMP1" -n one -- step=1 exit=-1 duration=-1 \
		log=/dev/null user=root time=1666666666
	assert_file - "$TMP1" <<-EOF
	$(step_header)
	1,one,-1,-1,/dev/null,root,1666666666,0
	EOF
fi

if testcase "write: replace step"; then
	: >"$TMP1"
	robsd_step -- -W -f "$TMP1" -n one -- step=1 exit=-1 duration=-1 \
		log=/dev/null user=root time=1666666666
	robsd_step -- -W -f "$TMP1" -n one -- exit=0
	assert_file - "$TMP1" <<-EOF
	$(step_header)
	1,one,0,-1,/dev/null,root,1666666666,0
	EOF
fi

if testcase "write: order by id"; then
	: >"$TMP1"
	robsd_step -- -W -f "$TMP1" -n two -- step=2 exit=-1 duration=-1 \
		log=/dev/null user=root time=1666666666
	robsd_step -- -W -f "$TMP1" -n one -- step=1 exit=-1 duration=-1 \
		log=/dev/null user=root time=1666666666
	assert_file - "$TMP1" <<-EOF
	$(step_header)
	1,one,-1,-1,/dev/null,root,1666666666,0
	2,two,-1,-1,/dev/null,root,1666666666,0
	EOF
fi

if testcase "write: invalid name missing"; then
	: >"$TMP1"
	robsd_step -e -- -W -f "$TMP1" >"$OUT"
	if ! grep -q usage "$OUT"; then
		fail - "expected usage" <"$OUT"
	fi
fi

if testcase "write: invalid key value"; then
	: >"$TMP1"
	robsd_step -e - -- -W -f "$TMP1" -n one -- key <<-EOF
	robsd-step: missing field separator in 'key'
	EOF
fi

if testcase "write: invalid missing fields"; then
	: >"$TMP1"
	robsd_step -e - -- -W -f "$TMP1" -n one -- step=1  <<-EOF
	robsd-step: invalid substitution, unknown variable 'exit'
	EOF
fi
