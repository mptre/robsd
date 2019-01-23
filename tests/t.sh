set -eu

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

	# $3 is intentionally unquoted since it's optional.
	printf '\tWANT:\t%s\n\tGOT:\t%s\n' "$1" "$2" 1>&2 | fail - ${3:-}
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

# report [-] [-f] message...
report() {
	local _force=0 _prefix _stdin=0

	while [ $# -gt 0 ]; do
		case "$1" in
		-)	_stdin=1;;
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

	# Try very hard to output everything to stderr in one go.
	{
		printf '%s: %s: %s' "$_prefix" "$TNAME" "$TCASE"
		[ $# -gt 0 ] && printf ': %s' "$*"
		echo
		[ $_stdin -eq 1 ] && cat
	} >$_TMP1
	cat <$_TMP1 1>&2
}

# Internal and external temporary files.
_TMP1="$(mktemp -t release.XXXXXX)"
TMP1="$(mktemp -t release.XXXXXX)"

trap 'atexit $_TMP1 $TMP1' EXIT

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
