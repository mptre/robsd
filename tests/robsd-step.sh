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
	if [ -e "$_stdin" ]; then
		assert_file "$_stdin" "$_stdout"
	else
		cat "$_stdout"
	fi
}

if testcase "read: positive index"; then
	default_steps >"$TMP1"
	robsd_step -- -R -f "$TMP1" -i 1 <<-'EOF' >"$OUT"
	${step}, ${name}, ${exit}, ${duration}, ${log}, ${user}, ${time}
	EOF
	assert_file - "$OUT" <<-EOF
	1, one, 0, 1, , root, 1666666666
	EOF
fi

if testcase "read: read: positive index boundary"; then
	default_steps >"$TMP1"
	robsd_step -- -R -f "$TMP1" -i 2 <<-'EOF' >"$OUT"
	${name}
	EOF
	assert_file - "$OUT" <<-EOF
	two
	EOF
fi

if testcase "read: positive index out of bounds"; then
	default_steps >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -i 3 <<-'EOF'
	robsd-step: step with id 3 not found
	EOF
fi

if testcase "read: negtive index"; then
	default_steps >"$TMP1"
	robsd_step -- -R -f "$TMP1" -i -1 <<-'EOF' >"$OUT"
	${name}
	EOF
	assert_file - "$OUT" <<-EOF
	two
	EOF
fi

if testcase "read: negative index boundary"; then
	default_steps >"$TMP1"
	robsd_step -- -R -f "$TMP1" -i -2 <<-'EOF' >"$OUT"
	${name}
	EOF
	assert_file - "$OUT" <<-EOF
	one
	EOF
fi

if testcase "read: negative index out of bounds"; then
	default_steps >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -i -3 <<-'EOF'
	robsd-step: step with id -3 not found
	EOF
fi

if testcase "read: index too large"; then
	default_steps >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -i $((1 << 31)) <<-'EOF'
	robsd-step: id 2147483648 too large
	EOF
fi

if testcase "read: index too small"; then
	default_steps >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -i -$((1 << 31)) <<-'EOF'
	robsd-step: id -2147483648 too small
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
	robsd_step -e - -- -R -f "$TMP1" -i 1 -n name <<-EOF
	robsd-step: -i and -n are mutually exclusive
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
	robsd_step -e - -- -R -f "$TMP1" -i 1 <<-EOF
	robsd-step: ${TMP1}:1: unterminated value
	EOF
fi

if testcase "read: invalid unterminated row"; then
	{ default_steps; printf '1'; } >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -i 1 <<-EOF
	robsd-step: ${TMP1}:4: unterminated value
	EOF
fi

if testcase "read: invalid empty row"; then
	{ default_steps; printf '\n'; } >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -i 1 <<-EOF
	robsd-step: ${TMP1}:4: want VALUE, got NEWLINE
	EOF
fi

if testcase "read: invalid column"; then
	{ printf 'step\n'; step_serialize -H -s 1 -n one; } >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -i 1 <<-EOF
	robsd-step: ${TMP1}:2: unknown column 1
	EOF
fi

if testcase "read: invalid missing field"; then
	default_steps | sed -e 's/one,/,/' >"$TMP1"
	robsd_step -e - -- -R -f "$TMP1" -i 1 <<-EOF
	robsd-step: ${TMP1}:2: missing field 'name'
	EOF
fi

if testcase "read: invalid file not found"; then
	robsd_step -e - -- -R -f "${TMP1}.nein" -i 1 <<-EOF
	robsd-step: ${TMP1}.nein: No such file or directory
	EOF
fi

if testcase "write: new step"; then
	: >"$TMP1"
	robsd_step -- -W -f "$TMP1" -i 1 -- name=one exit=-1 duration=-1 \
		log=/dev/null user=root time=1666666666
	assert_file - "$TMP1" <<-EOF
	$(step_header)
	1,one,-1,-1,0,/dev/null,root,1666666666,0
	EOF
fi

if testcase "write: replace step"; then
	: >"$TMP1"
	robsd_step -- -W -f "$TMP1" -i 1 -- name=one exit=-1 duration=-1 \
		log=/dev/null user=root time=1666666666
	robsd_step -- -W -f "$TMP1" -i 1 -- exit=0
	assert_file - "$TMP1" <<-EOF
	$(step_header)
	1,one,0,-1,0,/dev/null,root,1666666666,0
	EOF
fi

if testcase "write: order by id"; then
	: >"$TMP1"
	robsd_step -- -W -f "$TMP1" -i 2 -- name=two exit=-1 duration=-1 \
		log=/dev/null user=root time=1666666666
	robsd_step -- -W -f "$TMP1" -i 1 -- name=one exit=-1 duration=-1 \
		log=/dev/null user=root time=1666666666
	assert_file - "$TMP1" <<-EOF
	$(step_header)
	1,one,-1,-1,0,/dev/null,root,1666666666,0
	2,two,-1,-1,0,/dev/null,root,1666666666,0
	EOF
fi

if testcase "write: duplicate name"; then
	: >"$TMP1"
	robsd_step -- -W -f "$TMP1" -i 1 -- name=one exit=-1 duration=-1 \
		log=/dev/null user=root time=1666666666
	robsd_step -- -W -f "$TMP1" -i 2 -- name=one exit=-1 duration=-1 \
		log=/dev/null user=root time=1666666666
	assert_file - "$TMP1" <<-EOF
	$(step_header)
	1,one,-1,-1,0,/dev/null,root,1666666666,0
	2,one,-1,-1,0,/dev/null,root,1666666666,0
	EOF
fi

if testcase "write: optional fields"; then
	: >"$TMP1"
	robsd_step -- -W -f "$TMP1" -i 1 -- name=one exit=-1 duration=-1 \
		user=root time=1666666666
	if ! step_header | tr ',' '\n' | sed -e 's/\(.*\)/${\1}/' |
	   robsd_step -R -f "$TMP1" -n one >/dev/null
	then
		fail "expected all fields to be interpolated"
	fi
fi

if testcase "write: invalid name missing"; then
	: >"$TMP1"
	robsd_step -e -- -W -f "$TMP1" >"$OUT"
	if ! grep -q usage "$OUT"; then
		fail - "expected usage" <"$OUT"
	fi
fi

if testcase "write: invalid field"; then
	: >"$TMP1"
	robsd_step -e - -- -W -f "$TMP1" -i 1 -- key <<-EOF
	robsd-step: missing field separator in 'key'
	EOF
fi

if testcase "write: invalid missing fields"; then
	: >"$TMP1"
	robsd_step -e - -- -W -f "$TMP1" -i 1 -- name=one <<-EOF
	robsd-step: invalid substitution, unknown variable 'exit'
	EOF
fi

if testcase "list: robsd"; then
	robsd_config - <<-EOF
	robsddir "$TSHDIR"
	EOF

	robsd_step -- -L -C "$ROBSDCONF" -m robsd >"$TMP1"
	if ! [ -s "$TMP1" ]; then
		fail "expected steps"
	fi
fi

if testcase "list: robsd-cross"; then
	robsd_config -C - <<-EOF
	robsddir "$TSHDIR"
	EOF

	robsd_step -- -L -C "$ROBSDCONF" -m robsd-cross >"$TMP1"
	if ! [ -s "$TMP1" ]; then
		fail "expected steps"
	fi
fi

if testcase "list: robsd-ports"; then
	robsd_config -P - <<-EOF
	robsddir "$TSHDIR"
	ports { "devel/robsd" }
	EOF

	robsd_step -- -L -C "$ROBSDCONF" -m robsd-ports >"$TMP1"
	if ! [ -s "$TMP1" ]; then
		fail "expected steps"
	fi
fi

if testcase "list: robsd-regress"; then
	robsd_config -R - <<-EOF
	robsddir "$TSHDIR"
	regress "lib/libc/locale" no-parallel
	regress "gnu/usr.bin/perl" no-parallel
	regress "bin/csh"
	regress "bin/ksh"
	EOF

	robsd_step -- -L -C "$ROBSDCONF" -m robsd-regress |
	cut -d ' ' -f 2- |
	grep / >"$TMP1"

	assert_file - "$TMP1" <<-EOF
	bin/csh parallel
	bin/ksh parallel
	lib/libc/locale
	gnu/usr.bin/perl
	EOF
fi

if testcase "list: robsd-regress parallel disabled"; then
	robsd_config -R - <<-EOF
	robsddir "$TSHDIR"
	parallel no
	regress "test/one" no-parallel
	regress "test/two"
	EOF

	robsd_step -- -L -C "$ROBSDCONF" -m robsd-regress |
	cut -d ' ' -f 2- |
	grep / >"$TMP1"

	assert_file - "$TMP1" <<-EOF
	test/one
	test/two
	EOF
fi

if testcase "list: canvas"; then
	robsd_config -c - <<-EOF
	step "first" command { "true" }
	step "second" command { "true" } parallel
	EOF

	robsd_step - -- -L -C "$ROBSDCONF" -m canvas <<-EOF
	1 first
	2 second parallel
	3 end
	EOF
fi

if testcase "list: offset"; then
	robsd_config - <<-EOF
	robsddir "$TSHDIR"
	EOF

	robsd_step - -- -L -C "$ROBSDCONF" -m robsd -o 17 <<-EOF
	17 end
	EOF
fi

if testcase "list: invalid offset"; then
	robsd_config - <<-EOF
	robsddir "$TSHDIR"
	EOF

	robsd_step -e - -- -L -C "$ROBSDCONF" -m robsd -o 0 <<-EOF
	robsd-step: offset 0 too small
	EOF

	robsd_step -e - -- -L -C "$ROBSDCONF" -m robsd -o 100 <<-EOF
	robsd-step: offset 100 too large
	EOF

	robsd_step -e - -- -L -C "$ROBSDCONF" -m robsd -o 4294967296 <<-EOF
	robsd-step: offset 4294967296 too large
	EOF
fi
