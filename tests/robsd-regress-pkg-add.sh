portable no

_step="${EXECDIR}/robsd-regress-pkg-add.sh"

if testcase "basic"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "one" packages { "uniq" "dup" }
	regress "two" packages { "dup" }
	EOF
	_builddir="${TSHDIR}/2022-11-21"
	mkdir -p "${_builddir}/tmp"
	echo "${_builddir}" >"${TSHDIR}/.running"

	cat <<-EOF >"${TSHDIR}/pkg_add"
	exit 0
	EOF
	chmod u+x "${TSHDIR}/pkg_add"

	if ! (setmode "robsd-regress" &&
	      env PATH="${TSHDIR}:${PATH}" sh -eux -o pipefail "${_step}") \
	     >"${TMP1}" 2>&1; then
		fail - "expected exit zero" <"${TMP1}"
	fi

	if ! grep -q SUCCESS "${TMP1}"; then
		fail - "expected success" <"${TMP1}"
	fi

	assert_file - "${_builddir}/tmp/packages" <<-EOF
	dup
	uniq
	EOF
fi

if testcase "env present"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress-env { "FOO=1" "BAR=2" }
	regress "one" packages { "one" }
	EOF
	_builddir="${TSHDIR}/2022-11-21"
	mkdir -p "${_builddir}/tmp"
	echo "${_builddir}" >"${TSHDIR}/.running"

	cat <<-EOF >"${TSHDIR}/pkg_add"
	env
	EOF
	chmod u+x "${TSHDIR}/pkg_add"

	if ! (setmode "robsd-regress" &&
	      env PATH="${TSHDIR}:${PATH}" sh -eux -o pipefail "${_step}") \
	     >"${TMP1}" 2>&1; then
		fail - "expected exit zero" <"${TMP1}"
	fi

	if ! grep -q 'FOO=1' "${TMP1}" || ! grep -q 'BAR=2' "${TMP1}"; then
		fail - "expected env to be honored" <"${TMP1}"
	fi
fi

if testcase "failure"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "one" packages { "one" }
	EOF
	_builddir="${TSHDIR}/2022-11-21"
	mkdir -p "${_builddir}/tmp"
	echo "${_builddir}" >"${TSHDIR}/.running"

	cat <<-EOF >"${TSHDIR}/pkg_add"
	exit 1
	EOF
	chmod u+x "${TSHDIR}/pkg_add"

	if ! (setmode "robsd-regress" &&
	      env PATH="${TSHDIR}:${PATH}" sh -eux -o pipefail "${_step}") \
	     >"${TMP1}" 2>&1; then
		fail - "expected exit zero" <"${TMP1}"
	fi

	if ! grep -q SKIPPED "${TMP1}"; then
		fail - "expected skipped" <"${TMP1}"
	fi
fi
