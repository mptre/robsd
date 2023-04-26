portable no

_step="${EXECDIR}/robsd-regress-obj.sh"

if testcase "basic"; then
	robsd_config -R - <<-EOF
	robsddir "${TSHDIR}"
	regress "good"
	regress "absent"
	EOF
	mkdir -p "${TSHDIR}/regress/good"
	cat <<EOF >"${TSHDIR}/regress/good/Makefile"
obj:
EOF

	if ! (setmode "robsd-regress" && sh -eux -o pipefail "$_step") \
	     >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
fi
