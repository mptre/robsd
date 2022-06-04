robsd_mock >"$TMP1"; read -r _ BINDIR ROBSDDIR <"$TMP1"

ROBSDCROSS="${EXECDIR}/robsd-cross"

if testcase "basic"; then
	robsd_config -C - <<-EOF
	robsddir "${ROBSDDIR}"
	execdir "${EXECDIR}"
	EOF
	mkdir "$ROBSDDIR"
	cat <<EOF >"${TSHDIR}/Makefile.cross"
cross-dirs:
	@echo cross-dirs
cross-tools:
	@echo cross-tools
cross-distrib:
	@echo cross-distrib
cross-env:
	@echo CROSSENV=1
EOF
	mkdir -p "${TSHDIR}/sys/arch/amd64/compile/GENERIC.MP"
	cat <<EOF >"${TSHDIR}/sys/arch/amd64/compile/GENERIC.MP/Makefile"
all:
	@echo all
cross-env:
	@echo cross-env
obj:
	@echo obj
config:
	@echo config
EOF

	if ! PATH="${BINDIR}:${PATH}" sh "$ROBSDCROSS" -d amd64 >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi

	_builddir="$(find "${ROBSDDIR}" -type d -mindepth 1 -maxdepth 1)"
	assert_file - "${_builddir}/target" <<-EOF
	amd64
	EOF
fi
