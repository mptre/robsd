portable no

_step="${EXECDIR}/robsd-regress-pkg-add.sh"

if testcase "basic"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "one" packages { "uniq" "dup" }
	regress "two" packages { "dup" }
	EOF
	_builddir="${TSHDIR}/2022-11-21"
	echo "${_builddir}" >"${TSHDIR}/.running"
	mkdir -p "${_builddir}/tmp"

	cat <<-EOF >"${TSHDIR}/pkg_add"
	exit 0
	EOF
	chmod u+x "${TSHDIR}/pkg_add"

	if ! (setmode "robsd-regress" &&
	      env PATH="${TSHDIR}:${PATH}" sh -eux -o pipefail "${_step}") \
	     >"${TMP1}" 2>&1; then
		fail - "expected exit zero" <"${TMP1}"
	fi

	assert_file - "${_builddir}/tmp/packages" <<-EOF
	dup
	uniq
	EOF
fi
