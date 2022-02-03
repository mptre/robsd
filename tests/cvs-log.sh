# Stub for su which in turn is expected to call `xargs cvs log'.
su() {
	local _file

	if echo "$3" | grep -s "'>2019-07-20 11:56:01'"; then
		return 0
	elif ! echo "$3" | grep -s "'>2019-07-14 00:00:00'"; then
		fail "invalid date: ${3}"
		return 1
	fi

	while read -r _file; do
		case "$_file" in
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
	BUILDDIR="${ROBSDDIR}/2019-07-21"; export BUILDDIR
	# shellcheck disable=SC2086
	mkdir -p ${ROBSDDIR}/2019-07-{19,20,21}
	cat <<-EOF >"${ROBSDDIR}/2019-07-20/steps"
	step="2" name="cvs" skip="1"
	EOF
	cat <<-EOF >"${ROBSDDIR}/2019-07-19/steps"
	step="2" name="cvs" log="${ROBSDDIR}/2019-07-19/cvs.log" time="1563616561"
	EOF
	cat <<-EOF >"${ROBSDDIR}/2019-07-19/cvs.log"
	Date: 2019/07/14 00:00:00
	Date: 2019/07/13 23:59:59
	EOF

	cat <<-EOF >"$TMP1"
	P bin/ed/ed.1
	P bin/ed/ed.c
	P sbin/dhclient/clparse.c
	EOF

	cat <<-EOF >"${TSHDIR}/exp"
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

	cvs_log -r "$ROBSDDIR" -t "${TSHDIR}/.cvs" \
		-c "$TSHDIR" -h example.com:/cvs -u nobody <"$TMP1" >"${TSHDIR}/act"
	assert_file "${TSHDIR}/exp" "${TSHDIR}/act"
fi

if testcase "previous build absent"; then
	if ! cvs_log -r "$ROBSDDIR" -t "${TSHDIR}/.cvs" \
	   -c "$TSHDIR" -h example.com:/cvs -u nobody >"$TMP1" 2>&1; then
		fail - "expected exit zero" <"$TMP1"
	fi
fi

# If the previous build didn't update anything, there's no date header to use
# as the threshold.
if testcase "previous build no updates"; then
	mkdir "${TSHDIR}/.cvs"
	BUILDDIR="${ROBSDDIR}/2019-07-21"; export BUILDDIR
	# shellcheck disable=SC2086
	mkdir -p ${ROBSDDIR}/2019-07-{20,21}
	cat <<-EOF >"${ROBSDDIR}/2019-07-20/steps"
	step="2" name="cvs" log="${ROBSDDIR}/2019-07-20/cvs.log" time="1563616561"
	EOF
	cat <<-EOF >"${ROBSDDIR}/2019-07-20/cvs.log"
	missing date header
	EOF

	cat <<-EOF >"$TMP1"
	P bin/ed/ed.1
	P bin/ed/ed.c
	P sbin/dhclient/clparse.c
	EOF

	if ! cvs_log -r "$ROBSDDIR" -t "${TSHDIR}/.cvs" -u nobody -c /dev/null \
	   <"$TMP1" >"${TSHDIR}/act"; then
		fail - "expected exit zero" <"$TMP1"
	fi
	assert_file "/dev/null" "${TSHDIR}/act"
fi
