set -e

atexit() {
	assert_pass

	rm -f "$@"

	if [ $NERR -gt 0 ]; then
		exit 1
	else
		exit 0
	fi
}

testcase() {
	assert_pass

	NTEST=$((NTEST + 1))
	TCASE="$@"
	TERR=0
	TPASS=0

	return 0
}

assert_eq() {
	[ "$1" = "$2" ] && return 0

	fail
	printf '\tWANT:\t%s\n\tGOT:\t%s\n' "$1" "$2" 1>&2
}

assert_pass() {
	[ $NTEST -eq 0 ] && return 0
	[ $TPASS -eq 1 ] && return 0

	fail "pass never called"
}

pass() {
	report "$@"
}

fail() {
	NERR=$((NERR + 1))
	TERR=$((TERR + 1))
	report -f "$@"
}

report() {
	local _force=0 _prefix

	while [ $# -gt 0 ]; do
		case "$1" in
		-f)	_force=1;;
		*)	break;;
		esac
		shift
	done

	{ [ $_force -eq 0 ] && [ $TPASS -gt 0 ]; } && return 0
	TPASS=1

	if [ $TERR -eq 0 ]; then
		_prefix='PASS'
	else
		_prefix='FAIL'
		NERR=$((NERR + 1))
	fi

	{
		printf '%s: %s: %s' "$_prefix" "$TNAME" "$TCASE"
		[ $# -gt 0 ] && printf ': %s' "$@"
		echo
	} 1>&2
}

TMP1="$(mktemp -t release.XXXXXX)"

trap 'atexit $TMP1' EXIT

NERR=0		# total number of errors
NTEST=0		# total number of executed test cases
TCASE=""	# test case description
TNAME=""	# test file name
TERR=0		# number of failures for test case
TPASS=0		# test case called passed

. "${RELEASEDIR}/util.sh"

for a; do
	TNAME="${a##*/}"
	. "$a"
done
