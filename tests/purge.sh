if testcase "basic"; then
	mkdir -p ${BUILDDIR}/2019-03-0{1,2}
	for _d in ${BUILDDIR}/*; do
		for _f in 01-base.log 02-cvs.log report src.diff; do
			(cd "$_d" && echo "$_f" >$_f)
		done
		cat <<-EOF >"${_d}/stages"
		EOF
	done

	assert_eq "${BUILDDIR}/2019-03-01" "$(purge "$BUILDDIR" 1)"

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

if testcase "last stage failure"; then
	mkdir -p ${BUILDDIR}/2019-03-0{1,2}/reldir
	_d="${BUILDDIR}/2019-03-01"
	touch "${_d}/04-kernel.log"
	cat <<-EOF >"${_d}/stages"
	exit="1" log="${_d}/04-kernel.log"
	EOF

	assert_eq "${BUILDDIR}/2019-03-01" "$(purge "$BUILDDIR" 1)"

	_d="${BUILDDIR}/attic/2019-03-01"
	[ -e "${_d}/04-kernel.log" ] ||
		fail "expected ${_d}/04-kernel.log to be left"
fi

if testcase "missing log files"; then
	mkdir -p ${BUILDDIR}/2019-03-0{1,2}/reldir

	assert_eq "${BUILDDIR}/2019-03-01" "$(purge "$BUILDDIR" 1)"
	assert_eq "" "$(find "${BUILDDIR}/attic/2019-03-01" -type f)"
fi

if testcase "attic already present"; then
	mkdir -p ${BUILDDIR}/2019-03-0{1,2}
	mkdir -p ${BUILDDIR}/attic

	assert_eq "${BUILDDIR}/2019-03-01" "$(purge "$BUILDDIR" 1)"

	[ -d "${BUILDDIR}/2019-03-02" ] ||
		fail "expected 2019-03-02 to be left"
	[ -d "${BUILDDIR}/attic/2019-03-01" ] ||
		fail "expected 2019-03-01 to be moved"
fi
