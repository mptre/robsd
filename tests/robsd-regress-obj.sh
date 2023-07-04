portable no

_step="${EXECDIR}/robsd-regress-obj.sh"

if testcase "basic"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "good"
	regress "absent"
	EOF
	mkdir -p "${TSHDIR}/regress/good"
	printf 'obj:\n' >"${TSHDIR}/regress/good/Makefile"

	if ! (setmode "robsd-regress" && sh -eux -o pipefail "$_step") \
	     >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
fi

if testcase "makefile bsd wrapper"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "one" obj { "two" }
	EOF
	mkdir -p "${TSHDIR}/regress/one"
	printf 'obj:\n\tmkdir obj\n' >"${TSHDIR}/regress/one/Makefile.bsd-wrapper"
	mkdir -p "${TSHDIR}/two"
	printf 'obj:\n\tmkdir obj\n' >"${TSHDIR}/two/Makefile.bsd-wrapper"

	if ! (setmode "robsd-regress" && sh -eux -o pipefail "$_step") \
	     >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
	if ! [ -d "${TSHDIR}/regress/one/obj" ]; then
		fail "expected regress/one/obj directory"
	fi
	if ! [ -d "${TSHDIR}/two/obj" ]; then
		fail "expected two/obj directory"
	fi
fi
