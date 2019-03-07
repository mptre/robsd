if testcase "basic"; then
	mkdir -p ${BUILDDIR}/2019-03-0{1,2}
	for _d in ${BUILDDIR}/*; do
		for _f in 01-base.log 02-cvs.log report src.diff stages; do
			(cd "$_d" && echo "$_f" >$_f)
		done
	done

	purge "$BUILDDIR" 1

	[ -d "${BUILDDIR}/2019-03-02" ] ||
		fail "expected 2019-03-02 to be left"

	[ -d "${BUILDDIR}/attic/2019-03-01" ] ||
		fail "expected 2019-03-01 to be moved"

	for _f in 01-base.log; do
		_p="${BUILDDIR}/attic/2019-03-01/${_f}"
		[ -e "$_p" ] && fail "expected ${_p} to be removed"
	done

	for _f in 02-cvs.log report src.diff stages; do
		_p="${BUILDDIR}/attic/2019-03-01/${_f}"
		[ -e "$_p" ] || fail "expected ${_p} to be left"
	done
fi

if testcase "missing log files"; then
	mkdir -p ${BUILDDIR}/2019-03-0{1,2}/reldir

	purge "$BUILDDIR" 1

	assert_eq "" "$(find "${BUILDDIR}/attic/2019-03-01" -type f)"
fi
