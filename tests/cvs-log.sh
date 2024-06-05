portable no

# Stub for su which in turn is expected to call `xargs cvs log'.
su() {
	local _file

	if echo "$3" | grep -s "'>2019-07-20 09:56:01'"; then
		return 0
	elif ! echo "$3" | grep -s "'>2019-07-14 00:00:00'"; then
		fail "invalid date: ${3}"
		return 1
	fi

	while read -r _file; do
		case "${_file}" in
		bin/ed/ed.*)
			cat <<-EOF
			Working file: ${_file}
			----------------------------
			revision 1.1
			date: 2019/07/15 04:00:00;  author: anton;  commitid: chEXfDinAk4DzfHQ;
			1. single commit for ed
			============================
			EOF
			;;
		regress/usr.bin/mandoc/char/N/basic.out_ascii)
			cat <<-EOF
			Working file: regress/usr.bin/mandoc/char/N/basic.out_ascii
			----------------------------
			revision 1.6
			date: 2023/11/13 20:35:33;  author: schwarze;  commitid: 0LuRz4KlqQVuu9kQ;
			reduce the man(7) global indentation from 7n to 5n, see man_term.c rev. 1.197
			============================
			EOF
			;;
		regress/usr.bin/mandoc/tbl/opt/invalid.out_ascii)
			cat <<-EOF
			Working file: regress/usr.bin/mandoc/tbl/opt/invalid.out_ascii
			----------------------------
			revision 1.4
			date: 2023/11/13 20:35:36;  author: schwarze;  commitid: 0LuRz4KlqQVuu9kQ;
			reduce the man(7) global indentation from 7n to 5n, see man_term.c rev. 1.197
			============================
			EOF
			;;
		sbin/dhclient/clparse.c)
			cat <<-EOF
			Working file: ${_file}
			----------------------------
			revision 1.2
			date: 2019/07/15 06:00:00;  author: anton;  commitid: GsUu9lB5EDnr7xWy;
			3. latest commit for dhclient

			... with multiple lines
			----------------------------
			revision 1.1
			date: 2019/07/15 05:00:00;  author: anton;  commitid: PmubCouD66EW1LlW;
			2. oldest commit for dhclient
			date: 2019/07/15 04:00:00;  author: anton;
			============================
			EOF
			;;
		*)
			echo "cvs: ${_file}: unknown file" 1>&2
			return 1
		esac
	done
}

if testcase "basic"; then
	mkdir "${TSHDIR}/.cvs"
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	echo "${TSHDIR}/2019-07-21" >"${TSHDIR}/.running"
	# shellcheck disable=SC2086
	mkdir -p ${TSHDIR}/2019-07-{19,20,21}
	step_serialize -n cvs -i 1 >"$(step_path "${TSHDIR}/2019-07-20")"
	step_serialize -n cvs -l cvs.log -t 1563616561 \
		>"$(step_path "${TSHDIR}/2019-07-19")"
	cat <<-EOF >"${TSHDIR}/2019-07-19/cvs.log"
	Date: 2019/07/14 00:00:00
	Date: 2019/07/13 23:59:59
	EOF

	cat <<-EOF >"${TMP1}"
	P bin/ed/ed.1
	P bin/ed/ed.c
	P regress/usr.bin/mandoc/char/N/basic.out_ascii
	P regress/usr.bin/mandoc/tbl/opt/invalid.out_ascii
	P sbin/dhclient/clparse.c
	EOF

	cat <<-EOF >"${TSHDIR}/exp"
	commit 0LuRz4KlqQVuu9kQ
	Author: schwarze
	Date: 2023/11/13 20:35:36

	  reduce the man(7) global indentation from 7n to 5n, see man_term.c rev. 1.197

	  regress/usr.bin/mandoc/char/N/basic.out_ascii
	  regress/usr.bin/mandoc/tbl/opt/invalid.out_ascii

	commit GsUu9lB5EDnr7xWy
	Author: anton
	Date: 2019/07/15 06:00:00

	  3. latest commit for dhclient

	  ... with multiple lines

	  sbin/dhclient/clparse.c

	commit PmubCouD66EW1LlW
	Author: anton
	Date: 2019/07/15 05:00:00

	  2. oldest commit for dhclient

	  sbin/dhclient/clparse.c

	commit chEXfDinAk4DzfHQ
	Author: anton
	Date: 2019/07/15 04:00:00

	  1. single commit for ed

	  bin/ed/ed.1
	  bin/ed/ed.c

	EOF

	cvs_log -t "${TSHDIR}/.cvs" -c "${TSHDIR}" -h example.com:/cvs \
		-u nobody <"${TMP1}" >"${TSHDIR}/act"
	assert_file "${TSHDIR}/exp" "${TSHDIR}/act"
fi

if testcase "previous build absent"; then
	if ! cvs_log -t "${TSHDIR}/.cvs" -c "${TSHDIR}" -h example.com:/cvs \
	   -u nobody >"${TMP1}" 2>&1
	then
		fail - "expected exit zero" <"${TMP1}"
	fi
fi

# If the previous build didn't update anything, there's no date header to use
# as the threshold.
if testcase "previous build no updates"; then
	mkdir "${TSHDIR}/.cvs"
	robsd_config - <<-EOF
	robsddir "${TSHDIR}"
	EOF
	echo "${TSHDIR}/2019-07-21" >"${TSHDIR}/.running"
	# shellcheck disable=SC2086
	mkdir -p ${TSHDIR}/2019-07-{20,21}
	step_serialize -n cvs -l cvs.log -t 1563616561 \
		>"$(step_path "${TSHDIR}/2019-07-20")"
	cat <<-EOF >"${TSHDIR}/2019-07-20/cvs.log"
	missing date header
	EOF

	cat <<-EOF >"${TMP1}"
	P bin/ed/ed.1
	P bin/ed/ed.c
	P sbin/dhclient/clparse.c
	EOF

	if ! cvs_log -t "${TSHDIR}/.cvs" -u nobody -c /dev/null \
	   <"${TMP1}" >"${TSHDIR}/act"
	then
		fail - "expected exit zero" <"${TMP1}"
	fi
	assert_file "/dev/null" "${TSHDIR}/act"
fi
