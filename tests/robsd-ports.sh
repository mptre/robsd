portable no

robsd_mock >"${TMP1}"; read -r _ BINDIR ROBSDDIR <"${TMP1}"

setup() {
	cat <<-'EOF' >"${BINDIR}/dpb"
	#!/bin/sh
	echo "$@"
	EOF
	chmod u+x "${BINDIR}/dpb"

	ROBSDCLEAN="${BINDIR}/robsd-clean"; export ROBSDCLEAN
	cp "${EXECDIR}/robsd-clean" "${ROBSDCLEAN}"
	chmod u+x "${ROBSDCLEAN}"
}

# robsd_ports [robsd-ports-argument ...]
robsd_ports() (
	PATH="${BINDIR}:${PATH}"
	export PATH PORTS TSHDIR
	sh "${EXECDIR}/robsd-ports" "$@"
)

if testcase "basic"; then
	robsd_config -P - <<-EOF
	robsddir "${ROBSDDIR}"
	ports { "devel/updated" "devel/outdated" }
	EOF
	mkdir "${ROBSDDIR}" "${TSHDIR}/ports"
	echo '# comment' >"${TSHDIR}/ports/Makefile"
	cat <<-EOF >"${TSHDIR}/ports.diff"
	--- Makefile
	+++ Makefile
	@@ -1 +1,2 @@
	 # comment 
	+# comment 
	EOF

	mkdir -p "${TSHDIR}/ports/packages/$(machine)/all"

	if ! robsd_ports -d -P "${TSHDIR}/ports.diff" -s cvs -s clean -s proot \
	   >"${TMP1}" 2>&1; then
		fail - "expected exit zero" <"${TMP1}"
	fi
	_builddir="$(find "${ROBSDDIR}" -type d -mindepth 1 -maxdepth 1)"

	# Remove unstable output.
	sed -e '/running as pid/d' "${_builddir}/robsd.log" >"${TMP1}"
	assert_file - "${TMP1}" <<-EOF
	robsd-ports: using directory ${_builddir} at step 1
	robsd-ports: using diff ${TSHDIR}/ports.diff rooted in ${TSHDIR}/ports
	robsd-ports: skipping steps: cvs clean proot
	robsd-ports: step env
	robsd-ports: step cvs skipped
	robsd-ports: step clean skipped
	robsd-ports: step proot skipped
	robsd-ports: step patch
	robsd-ports: step dpb
	robsd-ports: step distrib
	robsd-ports: step revert
	robsd-ports: reverting diff ${_builddir}/ports.diff.1
	robsd-ports: step dmesg
	robsd-ports: step end
	robsd-ports: trap exit 0
	EOF

	assert_file - "${_builddir}/tmp/ports" <<-EOF
	devel/updated
	devel/outdated
	EOF
fi

if testcase "retry"; then
	robsd_config -P - <<-EOF
	robsddir "${ROBSDDIR}"
	hook { "sh" "-x" "${TSHDIR}/robsd-ports-hook" "\${step-exit}" }
	ports { "devel/robsd" }
	EOF
	mkdir "${ROBSDDIR}"
	mkdir -p "${TSHDIR}/ports/packages/$(machine)/all"

	_prev_builddir="${ROBSDDIR}/2025-01-01.1"
	mkdir "${_prev_builddir}"
	{
		step_serialize -d 6 -e 0 -n dpb -s 6 -a 0
	} >"$(step_path "${_prev_builddir}")"

	cat <<-EOF >"${BINDIR}/dpb"
	#!/bin/sh
	if [ -e "${TSHDIR}/dpb" ]; then
		echo dpb >>"${TSHDIR}/dpb"
	else
		echo dpb >>"${TSHDIR}/dpb"
		exit 1
	fi
	EOF
	chmod u+x "${BINDIR}/dpb"

	# Make each date(1) invocation advance the wall clock with 10 seconds.
	cat <<-EOF >"${BINDIR}/date"
	#!/bin/sh
	[ -e "${TSHDIR}/date" ] || : >"${TSHDIR}/date"
	_iterations="\$(awk 'END {print NR}' ${TSHDIR}/date)"
	echo >>"${TSHDIR}/date"
	echo "\$((_iterations * 10))"
	EOF
	chmod u+x "${BINDIR}/date"

	cat <<-EOF >"${TSHDIR}/robsd-ports-hook"
	#!/bin/sh
	echo hook >>"${TSHDIR}/hook"
	if [ "\${1}" -eq 1 ]; then
		exit 125
	fi
	EOF

	if ! robsd_ports -d -s env -s cvs -s clean -s proot -s patch >"${TMP1}" 2>&1; then
		fail - "expected exit zero" <"${TMP1}"
	fi
	_builddir="$(find "${ROBSDDIR}" -type d -mindepth 1 -maxdepth 1 | grep -v "${_prev_builddir}")"

	_dpb_count="$(awk 'END {print NR}' <"${TSHDIR}/dpb")"
	assert_eq 2 "${_dpb_count}"

	step_eval -n dpb "$(step_path "${_builddir}")"
	_dpb_duration="$(step_value duration)"
	assert_eq 0 "$(step_value exit)"
	assert_eq "$((40 - 6))" "$(step_value delta)"

	step_eval -n distrib "$(step_path "${_builddir}")"
	_distrib_duration="$(step_value duration)"
	assert_eq 40 "${_dpb_duration}"
	if ! [ "${_distrib_duration}" -lt "${_dpb_duration}" ]; then
		fail "expected distrib duration to be smaller than dpb duration"
	fi
fi

if testcase "dpb arguments"; then
	robsd_config -P - <<-EOF
	robsddir "${ROBSDDIR}"
	dpb { "-J" "999999" }
	ports { "devel/robsd" }
	EOF
	mkdir "${ROBSDDIR}"
	mkdir -p "${TSHDIR}/ports/packages/$(machine)/all"

	cat <<-EOF >"${BINDIR}/dpb"
	#!/bin/sh
	echo "\${@}" | xargs printf '%s\n' >>"${TSHDIR}/dpb"
	EOF
	chmod u+x "${BINDIR}/dpb"

	if ! robsd_ports -d -s env -s cvs -s clean -s proot -s patch \
	     >"${TMP1}" 2>&1
	then
		fail - "expected exit zero" <"${TMP1}"
	fi

	cat -n "${TSHDIR}/dpb" |
	sed -n \
		-e 's/^[[:space:]]*//' \
		-e 's/[[:space:]][[:space:]]*/ /' \
		-e '/-J$/,$p' >"${TMP1}"
	assert_file - "${TMP1}" <<-EOF
	6 -J
	7 999999
	EOF
fi
