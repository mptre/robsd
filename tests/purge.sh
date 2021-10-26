if testcase "basic"; then
	# shellcheck disable=SC2086
	mkdir -p ${ROBSDDIR}/2019-03-0{1,2}/rel
	for _d in "$ROBSDDIR"/*; do
		for _f in 01-base.log 01-base.log.1 02-cvs.log 03-env.log comment rel/index.txt report src.diff.1; do
			(cd "$_d" && echo "$_f" >"$_f")
		done
		cat <<-EOF >"${_d}/steps"
		EOF
	done
	touch -t 201903012233.44 "${ROBSDDIR}/2019-03-01"

	assert_eq "${ROBSDDIR}/2019-03-01" "$(purge "$ROBSDDIR" 1)"

	[ -d "${ROBSDDIR}/2019-03-02" ] ||
		fail "expected 2019-03-02 to be left"

	[ -d "${ROBSDDIR}/attic/2019/03/01" ] ||
		fail "expected 2019-03-01 to be moved"

	for _f in 01-base.log 01-base.log.1 03-env.log; do
		_p="${ROBSDDIR}/attic/2019/03/01/${_f}"
		[ -e "$_p" ] && fail "expected ${_p} to be removed"
	done

	for _f in 02-cvs.log comment rel/index.txt report src.diff.1 steps; do
		_p="${ROBSDDIR}/attic/2019/03/01/${_f}"
		[ -e "$_p" ] || fail "expected ${_p} to be left"
	done

	assert_eq "Mar  1 22:33:44 2019" \
		"$(stat -f '%Sm' "${ROBSDDIR}/attic/2019/03/01")"
fi

if testcase "missing log files"; then
	# shellcheck disable=SC2086
	mkdir -p ${ROBSDDIR}/2019-03-0{1,2}/rel

	assert_eq "${ROBSDDIR}/2019-03-01" "$(purge "$ROBSDDIR" 1)"
	assert_eq "" "$(find "${ROBSDDIR}/attic/2019/03/01" -type f)"
fi

if testcase "attic already present"; then
	# shellcheck disable=SC2086
	mkdir -p ${ROBSDDIR}/2019-03-0{1,2}
	mkdir -p "${ROBSDDIR}/attic"

	assert_eq "${ROBSDDIR}/2019-03-01" "$(purge "$ROBSDDIR" 1)"

	[ -d "${ROBSDDIR}/2019-03-02" ] ||
		fail "expected 2019-03-02 to be left"
	[ -d "${ROBSDDIR}/attic/2019/03/01" ] ||
		fail "expected 2019-03-01 to be moved"
fi
